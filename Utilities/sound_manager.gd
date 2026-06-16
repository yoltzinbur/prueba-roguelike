extends Node

func play_sound(stream: AudioStream) -> void:
	var fx_player = AudioStreamPlayer.new()
	fx_player.stream = stream
	fx_player.bus = "Master"
	add_child(fx_player)
	fx_player.play()
	fx_player.finished.connect(fx_player.queue_free)
