-- local map = require('util.utils').mapkey
local map = vim.keymap.set
return {
  {
    'tpope/vim-fugitive',
    config = function()
      -- vim.schedule(function()
        map('n', '<leader>gb', '<cmd>Git blame<cr>', { desc = 'Git blame' })
        map('n', '<leader>gC', '<cmd>Gdiffsplit!<cr>', { desc = 'Conflict 3-way split' })
        map('n', '<leader>gd', '<cmd>Gdiff<cr>', { desc = 'Gdiff' })
        map('n', '<leader>gD', '<cmd>Git log --stat -p<cr>', { desc = 'Git log --stat -p' })
        map('n', '<leader>ge', ':Gedit ', { desc = 'Gedit' }) -- Gedit can take commit objects
        map('n', '<leader>gf', '<cmd>Git log --stat -p -- %<cr>', { desc = 'Git log --stat -p -- %' })
        map('n', '<leader>gF', '<cmd>Git log -- %<cr>', { desc = 'Git log  -- %' })
        map('n', '<leader>gl', [[<cmd>Git log --format="%h [%ad] [%an] %s"<cr>]], { desc = 'Git log oneline' })
        map('n', '<leader>gL', '<cmd>Git log<cr>', { desc = 'Git log' })
        map('n', '<leader>gO', function()
          vim.cmd 'Git difftool --name-only   --diff-filter=ACMR --relative | only | cfdo e! | cclose'
        end, { desc = 'Open all modified files' })

        map('n', '<leader>gg', '<cmd>G<cr>', { desc = 'G' })
        map('n', '<leader>gP', '<cmd>Git pull', { desc = 'Git pull' })
        map('n', '<leader>gp', '<cmd>Git -c push.default=current push<cr>', { desc = 'Git -c push.default=current push' })
        map('n', '<leader>gr', '<cmd>Gread<cr>', { desc = 'Gread' })
        map('n', '<leader>gw', '<cmd>Gwrite<cr>', { desc = 'Gwrite' })
        map('n', '<leader>gu', '<cmd>diffupdate<cr>', { desc = 'diffupdate' })
        map('n', '<leader>g2', '<cmd>diffget //2<cr>', { desc = 'diffget //2' })
        map('n', '<leader>g3', '<cmd>diffget //3<cr>', { desc = 'diffget //3' })
      -- end)
    end,
  },
}
