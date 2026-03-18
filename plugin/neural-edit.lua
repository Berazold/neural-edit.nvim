if vim.g.loaded_neural_edit == 1 then
	return
end
vim.g.loaded_neural_edit = 1

vim.api.nvim_create_user_command("NeuralGenerate", function()
	require("neural-edit").generate_code()
end, {
	desc = "Generate code using Neural Edit",
})

vim.api.nvim_create_user_command("NeuralRefactor", function()
	require("neural-edit").refactor_selection()
end, {
	range = true,
	desc = "Refactor selected text in-place using Neural Edit",
})

vim.api.nvim_create_user_command("NeuralExplain", function()
	require("neural-edit").explain_code()
end, {
	range = true,
	desc = "Explain selected code using Neural Edit",
})
