const VERTEX_AUDIO_PATHS = {
    start: "../../assets/audio/vertex-start.wav",
    "plug-in": "../../assets/audio/vertex-charge-plug.wav",
    "plug-out": "../../assets/audio/vertex-charge-unplug.wav"
};

function playVertexSound(name, volume = 0.9) {
    const src = VERTEX_AUDIO_PATHS[name];
    if (!src) return Promise.reject(new Error("Unknown Vertex sound"));
    try {
        const audio = new Audio(src);
        audio.preload = "auto";
        audio.volume = Math.max(0, Math.min(1, volume));
        return audio.play();
    } catch (error) {
        return Promise.reject(error);
    }
}
