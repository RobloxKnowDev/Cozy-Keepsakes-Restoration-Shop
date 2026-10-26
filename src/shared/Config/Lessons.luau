local Lessons = {
	Order = {
		{ Name = "Dirt", Objects = 1, Tools = { "ToothBrush" } },
		{ Name = "Sticker", Objects = 1, Tools = { "Tweezers" } },
		{ Name = "Turn", Objects = 1, Tools = { "Transform", "UvTorch" } },
		{ Name = "Ink", Objects = 1, Tools = { "Solvent", "CottonTip", "HeatGun" } },
		{ Name = "Scratch", Objects = 1, Tools = { "Polish" } },
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

function Lessons.GetStageName(Stage: number): string
	local Lesson = Lessons.Order[Stage]
	return if Lesson then Lesson.Name else "Done"
end

return Lessons
