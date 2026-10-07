return {
	DirtPasses = 6,
	CoverageGrid = 32,
	DirtLayerChance = 0.4,
	MaxDirtLayers = 4,
	DirtDecals = {
		DirtTop = true,
		DirtBottom = true,
		DirtLeft = true,
		DirtRight = true,
		DirtFront = true,
		DirtBack = true,
	},
	DirtTextures = {
		{ Image = "rbxassetid://116108341313813", Pattern = "Speckles", ZIndex = 2 },
		{ Image = "rbxassetid://136173134841464", Pattern = "Speckles", ZIndex = 3 },
		{ Image = "rbxassetid://136254375804004", Pattern = "Splashes", ZIndex = 4 },
		{ Image = "rbxassetid://87402903792010", Pattern = "Clumps", ZIndex = 5 },
		{ Image = "rbxassetid://79361514123085", Pattern = "Dust", ZIndex = 1 },
	},
	FinishAssist = {
		Start = 0.97,
		MinGain = 0.001,
		MaxGain = 0.008,
		Curve = 2,
		PingStart = 0.985,
	},
}
