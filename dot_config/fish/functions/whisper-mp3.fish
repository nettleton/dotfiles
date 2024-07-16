function whisper-mp3
  set wavtarget ( path change-extension .wav "$argv[1]")
  ffmpeg -i "$argv[1]" -ar 16000 "$wavtarget"
  whisper-cpp -m "$HOME/.cache/whisper/ggml-large-v3-q5_0.bin" "$wavtarget" --output-txt
end
