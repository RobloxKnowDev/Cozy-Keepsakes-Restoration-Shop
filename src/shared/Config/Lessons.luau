local Lessons = {
	Order = {
		{ Name = "Dirt", Objects = 1, Ramp = 0.4, Tools = { "ToothBrush" } },
		{ Name = "Sticker", Objects = 1, Ramp = 0.55, Tools = { "Tweezers" } },
		{ Name = "Turn", Objects = 1, Ramp = 0.7, Tools = { "Transform", "UvTorch" } },
		{ Name = "Ink", Objects = 1, Ramp = 0.7, Tools = { "Solvent", "CottonTip", "HeatGun" } },
		{ Name = "Scratch", Objects = 1, Ramp = 0.85, Tools = { "Polish" } },
	},
	StainKinds = { "Sticker", "Ink", "Scratch" },
	Hints = { "Flip", "Sell" },
}

function Lessons.GetStage(Learned: { [string]: boolean }): number
	for Index, Lesson in ipairs(Lessons.Order) do
		if not Learned[Lesson.Name] then
			return Index
		end
	end
	return #Lessons.Order + 1
end

function Lessons.LearnedAll(Learned: string?): boolean
	if Learned == nil then
		return false
	end
	local Done = {}
	for _, Name in ipairs(string.split(Learned, ",")) do
		Done[Name] = true
	end
	return Lessons.GetStage(Done) > #Lessons.Order
end

function Lessons.GetStageName(Stage: number): string
	local Lesson = Lessons.Order[Stage]
	return if Lesson then Lesson.Name else "Done"
end

return Lessons
