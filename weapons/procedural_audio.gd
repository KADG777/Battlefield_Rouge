class_name ProceduralAudio
extends RefCounted
## Original, license-free procedural SFX generated at runtime as 16-bit PCM.
## Ported from origin/sheji/systems/procedural_audio.gd (MIT).

const SAMPLE_RATE := 22050


static func generate(kind: String) -> AudioStreamWAV:
	match kind:
		"gunshot_sniper":
			return _noise_burst(0.34, 20.0, 1.0, 0.2)
		"gunshot_shotgun":
			return _noise_burst(0.22, 26.0, 0.95, 0.16)
		"gunshot_rifle":
			return _noise_burst(0.24, 24.0, 0.95, 0.22)
		"gunshot_ak47":
			return _noise_burst(0.13, 26.0, 0.8, 0.2)
		"gunshot_medium":
			return _noise_burst(0.16, 30.0, 0.7, 0.18)
		"gunshot_deagle":
			return _noise_burst(0.14, 30.0, 0.85, 0.15)
		"gunshot_small":
			return _noise_burst(0.1, 36.0, 0.5, 0.14)
		"explosion_grenade":
			return _noise_burst(0.65, 8.0, 0.95, 0.065)
		"reload":
			return _click_sequence([0.0, 0.13, 0.26, 0.38], 0.055)
		"bolt":
			return _click_sequence([0.0, 0.16, 0.3], 0.05)
		"dry":
			return _click_sequence([0.0], 0.04)
		"hit_flesh":
			return _noise_burst(0.06, 42.0, 0.4, 0.1)
		"hit_metal":
			return _noise_burst(0.09, 46.0, 0.5, 0.1)
		"melee_swing":
			return _knife_swing(0.22, 0.38, 0.55, 0.24)
		"melee_swing_heavy":
			return _knife_swing(0.34, 0.5, 0.4, 0.2)
		"melee_hit":
			return _knife_hit(0.15, 0.6)
	return _noise_burst(0.1, 30.0, 0.5, 0.15)


static func gunshot_for(kind: String) -> String:
	match kind:
		"sniper":
			return "gunshot_sniper"
		"shotgun":
			return "gunshot_shotgun"
		"deagle":
			return "gunshot_deagle"
		"ak47":
			return "gunshot_ak47"
		"rifle_bolt", "rifle_semi":
			return "gunshot_rifle"
		"smg":
			return "gunshot_medium"
		"pistol":
			return "gunshot_small"
	return "gunshot_medium"


static func _noise_burst(duration: float, decay: float, amp: float, lp_factor: float) -> AudioStreamWAV:
	var sample_count := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240712
	var lowpass := 0.0
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var envelope := exp(-t * decay)
		var white := rng.randf_range(-1.0, 1.0)
		lowpass += (white - lowpass) * lp_factor
		var value := int(clampf(lowpass * amp * envelope, -1.0, 1.0) * 32767.0) & 0xFFFF
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF
	return _make_wav(data)


static func _click_sequence(times: Array[float], click_duration: float) -> AudioStreamWAV:
	var total := times[times.size() - 1] + click_duration + 0.03
	var sample_count := int(total * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240712
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var value := 0.0
		for click_time in times:
			var local_t := t - click_time
			if local_t >= 0.0 and local_t < click_duration:
				var envelope := exp(-local_t * 70.0)
				value += rng.randf_range(-1.0, 1.0) * envelope * 0.7
		value = clampf(value, -1.0, 1.0)
		var sample := int(value * 32767.0) & 0xFFFF
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _make_wav(data)


## Knife swing built from two noise layers:
##  - a low "air whoosh" with a fast attack,
##  - a bright, short "blade shimmer" (high-frequency filtered noise).
## Heavy swings are longer, deeper and slower.
static func _knife_swing(duration: float, amp: float, shimmer_amount: float, lowpass_factor: float) -> AudioStreamWAV:
	var sample_count := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240712 + int(duration * 1000.0)
	var lowpass := 0.0
	var attack := 0.05

	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var env := t / attack if t < attack else exp(-(t - attack) * 10.0)

		var white := rng.randf_range(-1.0, 1.0)
		lowpass += (white - lowpass) * lowpass_factor
		var whoosh := lowpass * env * amp

		# High-frequency shimmer: subtract the lowpass from the raw noise and
		# fade it quickly for a metallic edge.
		var shimmer := (white - lowpass) * env * shimmer_amount * exp(-t * 16.0)

		var value := int(clampf(whoosh + shimmer, -1.0, 1.0) * 32767.0) & 0xFFFF
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF
	return _make_wav(data)


## Knife impact: a low-passed "thump" plus a very short bright click. Both are
## noise-based so they stay percussive instead of tonal.
static func _knife_hit(duration: float, amp: float) -> AudioStreamWAV:
	var sample_count := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240712 + 99
	var lowpass := 0.0

	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var white := rng.randf_range(-1.0, 1.0)

		lowpass += (white - lowpass) * 0.18
		var thump := lowpass * exp(-t * 34.0) * amp

		var click := (white - lowpass) * exp(-t * 70.0) * amp * 0.8

		var value := int(clampf(thump + click, -1.0, 1.0) * 32767.0) & 0xFFFF
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF
	return _make_wav(data)


static func _make_wav(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
