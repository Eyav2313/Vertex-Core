// Vertex session metrics daemon.
// Developer: Nuren Zarif Haque

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <exception>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <optional>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <thread>
#include <vector>

namespace {

constexpr std::string_view kVersion = "0.2.0";
constexpr std::string_view kDeveloper = "Nuren Zarif Haque";

struct CpuSample {
    std::uint64_t user = 0;
    std::uint64_t nice = 0;
    std::uint64_t system = 0;
    std::uint64_t idle = 0;
    std::uint64_t iowait = 0;
    std::uint64_t irq = 0;
    std::uint64_t softirq = 0;
    std::uint64_t steal = 0;
    std::uint64_t guest = 0;
    std::uint64_t guest_nice = 0;

    [[nodiscard]] std::uint64_t total() const {
        return user + nice + system + idle + iowait + irq + softirq + steal + guest + guest_nice;
    }

    [[nodiscard]] std::uint64_t idle_all() const {
        return idle + iowait;
    }
};

struct MemorySample {
    std::uint64_t total_kib = 0;
    std::uint64_t available_kib = 0;

    [[nodiscard]] double used_percent() const {
        if (total_kib == 0) {
            return 0.0;
        }
        const auto used = total_kib > available_kib ? total_kib - available_kib : 0;
        return (static_cast<double>(used) / static_cast<double>(total_kib)) * 100.0;
    }
};

struct Metrics {
    double cpu_percent = 0.0;
    double memory_percent = 0.0;
    double load_1m = 0.0;
    std::optional<double> temperature_c;
};

struct Options {
    bool waybar = false;
    bool stream = false;
    int interval_seconds = 2;
};

std::optional<CpuSample> read_cpu_sample() {
    std::ifstream file{"/proc/stat"};
    std::string label;
    CpuSample sample;

    if (!(file >> label) || label != "cpu") {
        return std::nullopt;
    }

    file >> sample.user
         >> sample.nice
         >> sample.system
         >> sample.idle
         >> sample.iowait
         >> sample.irq
         >> sample.softirq
         >> sample.steal
         >> sample.guest
         >> sample.guest_nice;

    return sample;
}

double cpu_percent_between(const CpuSample& previous, const CpuSample& current) {
    const auto total_delta = current.total() - previous.total();
    const auto idle_delta = current.idle_all() - previous.idle_all();

    if (total_delta == 0 || idle_delta > total_delta) {
        return 0.0;
    }

    return (static_cast<double>(total_delta - idle_delta) / static_cast<double>(total_delta)) * 100.0;
}

MemorySample read_memory_sample() {
    std::ifstream file{"/proc/meminfo"};
    std::string key;
    std::uint64_t value = 0;
    std::string unit;
    MemorySample sample;

    while (file >> key >> value >> unit) {
        if (key == "MemTotal:") {
            sample.total_kib = value;
        } else if (key == "MemAvailable:") {
            sample.available_kib = value;
        }
    }

    return sample;
}

double read_load_1m() {
    std::ifstream file{"/proc/loadavg"};
    double load = 0.0;
    file >> load;
    return load;
}

std::optional<double> read_temperature_c() {
    namespace fs = std::filesystem;

    const fs::path thermal_root{"/sys/class/thermal"};
    if (!fs::exists(thermal_root)) {
        return std::nullopt;
    }

    std::vector<fs::path> zones;
    for (const auto& entry : fs::directory_iterator{thermal_root}) {
        if (entry.is_directory() && entry.path().filename().string().rfind("thermal_zone", 0) == 0) {
            zones.push_back(entry.path());
        }
    }

    std::sort(zones.begin(), zones.end());

    for (const auto& zone : zones) {
        std::ifstream type_file{zone / "type"};
        std::string type;
        std::getline(type_file, type);

        const bool likely_cpu =
            type.find("x86_pkg_temp") != std::string::npos ||
            type.find("k10temp") != std::string::npos ||
            type.find("cpu") != std::string::npos ||
            type.find("CPU") != std::string::npos;

        if (!likely_cpu && !type.empty()) {
            continue;
        }

        std::ifstream temp_file{zone / "temp"};
        double milli_c = 0.0;
        if (temp_file >> milli_c) {
            return milli_c / 1000.0;
        }
    }

    return std::nullopt;
}

Metrics collect_metrics() {
    const auto first_cpu = read_cpu_sample();
    std::this_thread::sleep_for(std::chrono::milliseconds{160});
    const auto second_cpu = read_cpu_sample();
    const auto memory = read_memory_sample();

    Metrics metrics;
    if (first_cpu && second_cpu) {
        metrics.cpu_percent = cpu_percent_between(*first_cpu, *second_cpu);
    }
    metrics.memory_percent = memory.used_percent();
    metrics.load_1m = read_load_1m();
    metrics.temperature_c = read_temperature_c();
    return metrics;
}

std::string json_escape(std::string_view input) {
    std::string output;
    output.reserve(input.size());

    for (const char ch : input) {
        switch (ch) {
            case '"':
                output += "\\\"";
                break;
            case '\\':
                output += "\\\\";
                break;
            case '\n':
                output += "\\n";
                break;
            case '\r':
                output += "\\r";
                break;
            case '\t':
                output += "\\t";
                break;
            default:
                output += ch;
                break;
        }
    }

    return output;
}

std::string metric_class(const Metrics& metrics) {
    const bool critical_temp = metrics.temperature_c && *metrics.temperature_c >= 85.0;
    if (metrics.cpu_percent >= 90.0 || metrics.memory_percent >= 90.0 || critical_temp) {
        return "critical";
    }

    const bool warning_temp = metrics.temperature_c && *metrics.temperature_c >= 75.0;
    if (metrics.cpu_percent >= 75.0 || metrics.memory_percent >= 80.0 || warning_temp) {
        return "warning";
    }

    return "normal";
}

std::string render_waybar_json(const Metrics& metrics) {
    std::ostringstream text;
    text << "CPU " << std::fixed << std::setprecision(0) << metrics.cpu_percent
         << "%  MEM " << metrics.memory_percent << "%";

    std::ostringstream tooltip;
    tooltip << "Vertex performance metrics"
            << "\nCPU: " << std::fixed << std::setprecision(1) << metrics.cpu_percent << "%"
            << "\nMemory: " << metrics.memory_percent << "%"
            << "\nLoad 1m: " << metrics.load_1m;

    if (metrics.temperature_c) {
        tooltip << "\nCPU temp: " << *metrics.temperature_c << " C";
    }

    std::ostringstream json;
    json << "{\"text\":\"" << json_escape(text.str())
         << "\",\"tooltip\":\"" << json_escape(tooltip.str())
         << "\",\"class\":\"" << metric_class(metrics)
         << "\",\"percentage\":" << static_cast<int>(metrics.cpu_percent)
         << "}";

    return json.str();
}

std::string render_plain_text(const Metrics& metrics) {
    std::ostringstream output;
    output << "cpu=" << std::fixed << std::setprecision(1) << metrics.cpu_percent
           << "% memory=" << metrics.memory_percent
           << "% load1=" << metrics.load_1m;

    if (metrics.temperature_c) {
        output << " temp=" << *metrics.temperature_c << "C";
    }

    return output.str();
}

void print_help() {
    std::cout
        << "vertex-sessiond " << kVersion << "\n"
        << "Developer: " << kDeveloper << "\n\n"
        << "Usage:\n"
        << "  vertex-sessiond --waybar           Print one Waybar JSON metrics sample\n"
        << "  vertex-sessiond --waybar --stream  Stream Waybar JSON metrics samples\n"
        << "  vertex-sessiond --interval 2       Set stream interval in seconds\n"
        << "  vertex-sessiond --version          Print version\n";
}

Options parse_options(int argc, char** argv) {
    Options options;

    for (int index = 1; index < argc; ++index) {
        const std::string_view arg{argv[index]};

        if (arg == "--help" || arg == "-h") {
            print_help();
            std::exit(0);
        }

        if (arg == "--version") {
            std::cout << "vertex-sessiond " << kVersion << " (" << kDeveloper << ")\n";
            std::exit(0);
        }

        if (arg == "--waybar") {
            options.waybar = true;
            continue;
        }

        if (arg == "--stream") {
            options.stream = true;
            continue;
        }

        if (arg == "--interval") {
            if (index + 1 >= argc) {
                throw std::runtime_error{"--interval requires a value"};
            }
            options.interval_seconds = std::max(1, std::atoi(argv[++index]));
            continue;
        }

        throw std::runtime_error{"unknown argument: " + std::string{arg}};
    }

    return options;
}

void print_sample(const Options& options) {
    const auto metrics = collect_metrics();
    if (options.waybar) {
        std::cout << render_waybar_json(metrics) << '\n';
    } else {
        std::cout << render_plain_text(metrics) << '\n';
    }
    std::cout.flush();
}

} // namespace

int main(int argc, char** argv) {
    try {
        const auto options = parse_options(argc, argv);

        if (!options.stream) {
            print_sample(options);
            return 0;
        }

        while (true) {
            print_sample(options);
            std::this_thread::sleep_for(std::chrono::seconds{options.interval_seconds});
        }
    } catch (const std::exception& error) {
        std::cerr << "vertex-sessiond: " << error.what() << '\n';
        return 1;
    }
}
