--!strict
-- Spatial, capped audio. Plays only real assets from AudioCatalog; missing assets fall back to a
-- small visual cue (no invented IDs). Voice cap with priority + distance stealing, per-sound rate
-- limits, and a tight inflate limiter so mass respawns don't become constant noise.

local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local AudioController = {}
AudioController.__index = AudioController

local MAX_VOICES = 8
local MIN_INTERVAL = 0.045
local INFLATE_WINDOW, INFLATE_MAX = 0.5, 2
local MAX_DISTANCE = 120

function AudioController.new(Content: any, effects: any)
	local self = setmetatable({
		Catalog = Content.AudioCatalog,
		effects = effects,
		voices = {} :: { { sound: Sound, att: Attachment, priority: number, dist: number, busyUntil: number } },
		lastPlay = {} :: { [string]: number },
		inflateTimes = {} :: { number },
		sfxVolume = 0.8,
		musicVolume = 0.5,
		music = nil :: Sound?,
	}, AudioController)
	local sfx = SoundService:FindFirstChild("PopParadeSFX") or Instance.new("SoundGroup")
	sfx.Name = "PopParadeSFX"
	sfx.Parent = SoundService
	local music = SoundService:FindFirstChild("PopParadeMusic") or Instance.new("SoundGroup")
	music.Name = "PopParadeMusic"
	music.Parent = SoundService
	self.sfxGroup = sfx :: SoundGroup
	self.musicGroup = music :: SoundGroup
	for _ = 1, MAX_VOICES do
		local att = Instance.new("Attachment")
		att.Name = "PopParadeVoice"
		att.Parent = Workspace.Terrain
		local snd = Instance.new("Sound")
		snd.SoundGroup = sfx :: SoundGroup
		snd.RollOffMode = Enum.RollOffMode.InverseTapered
		snd.RollOffMinDistance = 10
		snd.RollOffMaxDistance = MAX_DISTANCE
		snd.Parent = att
		table.insert(self.voices, { sound = snd, att = att, priority = 0, dist = 0, busyUntil = 0 })
	end
	self.uiSound = Instance.new("Sound")
	self.uiSound.SoundGroup = sfx :: SoundGroup
	self.uiSound.Parent = SoundService
	return self
end

function AudioController.setVolumes(self: any, sfx: number?, music: number?)
	if sfx then
		self.sfxVolume = math.clamp(sfx, 0, 1)
		self.sfxGroup.Volume = self.sfxVolume
	end
	if music then
		self.musicVolume = math.clamp(music, 0, 1)
		self.musicGroup.Volume = self.musicVolume
	end
end

local function listenerPos(): Vector3
	local cam = Workspace.CurrentCamera
	return if cam then cam.CFrame.Position else Vector3.zero
end

-- Returns true if a real sound played; false if the visual fallback was used (or skipped).
function AudioController.play(self: any, id: string, position: Vector3?): boolean
	local d = self.Catalog.get(id)
	if not d then
		return false
	end
	local now = os.clock()
	if (self.lastPlay[id] or 0) + MIN_INTERVAL > now then
		return false
	end
	if id == "sfx.inflate" then
		local recent = {}
		for _, t in self.inflateTimes do
			if now - t < INFLATE_WINDOW then
				table.insert(recent, t)
			end
		end
		self.inflateTimes = recent
		if #recent >= INFLATE_MAX then
			return false
		end
		table.insert(self.inflateTimes, now)
	end
	self.lastPlay[id] = now
	local dist = if position then (position - listenerPos()).Magnitude else 0
	if dist > MAX_DISTANCE then
		return false
	end
	if d.assetId == nil then
		if position and d.visualFallback ~= "none" then
			self.effects:fallbackCue(d.visualFallback, position)
		end
		return false
	end
	-- pick a free voice, else steal the least important (lower priority, then farther)
	local pick = nil
	for _, v in self.voices do
		if v.busyUntil <= now then
			pick = v
			break
		end
	end
	if not pick then
		for _, v in self.voices do
			if v.priority < d.priority or (v.priority == d.priority and v.dist > dist) then
				if not pick or v.priority < pick.priority or (v.priority == pick.priority and v.dist > pick.dist) then
					pick = v
				end
			end
		end
	end
	if not pick then
		return false
	end
	local snd = pick.sound
	snd:Stop()
	snd.SoundId = d.assetId
	snd.Volume = d.volume
	snd.PlaybackSpeed = d.pitch + (math.random() * 2 - 1) * d.pitchJitter
	pick.att.WorldPosition = position or listenerPos()
	pick.priority = d.priority
	pick.dist = dist
	pick.busyUntil = now + 1.2
	snd:Play()
	return true
end

function AudioController.ui(self: any, id: string)
	local d = self.Catalog.get(id)
	if not d or d.assetId == nil then
		return
	end
	self.uiSound.SoundId = d.assetId
	self.uiSound.Volume = d.volume
	self.uiSound:Play()
end

-- Sound preview from the Sound panel: real sound if available, visual cue near the player otherwise.
function AudioController.preview(self: any, id: string)
	local d = self.Catalog.get(id)
	if not d then
		return
	end
	if d.assetId then
		self.uiSound.SoundId = d.assetId
		self.uiSound.Volume = d.volume
		self.uiSound.PlaybackSpeed = d.pitch
		self.uiSound:Play()
	else
		local cam = Workspace.CurrentCamera
		if cam then
			self.effects:fallbackCue(d.visualFallback, cam.CFrame.Position + cam.CFrame.LookVector * 10)
		end
	end
end

function AudioController.startMusic(self: any)
	local d = self.Catalog.get("music.hub")
	if not d or not d.assetId or self.music then
		return
	end
	local m = Instance.new("Sound")
	m.SoundId = d.assetId
	m.Looped = true
	m.Volume = d.volume
	m.SoundGroup = self.musicGroup
	m.Parent = SoundService
	m:Play()
	self.music = m
end

function AudioController.destroy(self: any)
	for _, v in self.voices do
		v.att:Destroy()
	end
	table.clear(self.voices)
	self.uiSound:Destroy()
	if self.music then
		self.music:Destroy()
	end
end

return AudioController
