--!strict
-- POP PARADE shared content (B-owned): presentation data, palettes and public layouts.
-- Mapped by Rojo to ReplicatedStorage.PopParade.Content (requested from A, see docs/b/CONTRACT_REQUESTS.md).
-- No authority lives here: no prices, odds, stat values, product IDs, rewards or secret coordinates.

return {
	Palette = require(script.Palette),
	Materials = require(script.Materials),
	Themes = require(script.Themes),
	VisualCatalog = require(script.VisualCatalog),
	AudioCatalog = require(script.AudioCatalog),
	Strings = require(script.Strings),
	Branding = require(script.Branding),
	Layouts = {
		Hub = require(script.Layouts.Hub),
		RubberStage001 = require(script.Layouts.RubberStage001),
		Parkour001 = require(script.Layouts.Parkour001),
	},
}
