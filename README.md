 <!-- LTeX: enabled=false -->
# nvim-tinygit <!-- LTeX: enabled=true -->
<!-- TODO uncomment shields when available in dotfyle.com -->
<!-- <a href="https://dotfyle.com/plugins/chrisgrieser/nvim-tinygit"><img src="https://dotfyle.com/plugins/chrisgrieser/nvim-tinygit/shield" /></a> -->

Lightweight git client for nvim for quick commits and other quality of life improvements.

`nvim-tinygit` should be considered beta status. It-works-on-my-machine™, but it has not yet been tested by many other users.

<!--toc:start-->
- [Features](#main-features)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Credits](#credits)
<!--toc:end-->

## Main Features
- Smart-Commit: Open a popup to enter a commit message. If there are no staged changed, stages all changes before doing so (`git add -A`).
- Commit Messages have syntax highlighting, indicators for [commit message overlength](https://stackoverflow.com/questions/2290016/git-commit-messages-50-72-formatting), and optionally enforce conventional commits keywords.
- Option to run `git push` in a non-blocking manner after committing.
- Quick amends.
- Search issues & PRs. Open the selected issue or PR in the browser.
- Open the GitHub URL of the current file or selection.
- Non-Goal: Become [neogit](https://github.com/TimUntersberger/neogit) or [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim). `tinygit` is intended to complement those plugins with some simple commands, not replace them.

## Installation

```lua
-- lazy.nvim
{
	"chrisgrieser/nvim-tinygit",
	dependencies = "stevearc/dressing.nvim",
},

-- packer
use {
	"chrisgrieser/nvim-tinygit",
	requires = "stevearc/dressing.nvim",
}
```

Optionally, install the Treesitter parser for git commits for some syntax highlighting of your commit messages, like for example emphasized conventional commit keywords: `TSInstall gitcommit`

## Usage

```lua
-- Open a commit popup. If there are no staged changes, stage all changes (`git add -A`) before the commit. Optionally runs `git push` afterwards.
-- 💡 You can use gitsigns.nvim's `add_hunk` command to stage changes.
require("tinygit").smartCommit({ push = false }) -- options default to `false`

-- Quick amends. `noedit = false` will open a commit message popup. 
-- Optionally runs `git push --force` afterwards (only recommended for single-person repos).
require("tinygit").amend ({ forcePush = false, noedit = false }) -- options default to `false`

-- Search issues & PRs. 
-- (Uses telescope, if you configure dressing.nvim to use telescope as selector.)
require("tinygit").issuesAndPrs("all") -- all|closed|open (default: all)

-- Open at GitHub and copy the URL to the system clipboard.
-- Normal mode: the current file, visual mode: the current selection.
require("tinygit").githubUrl("file") -- file|repo (default: file)

-- `git push`
require("tinygit").push({ pullBefore = false, force = false }) -- options default to `false`
```

## Configuration

```lua
local defaultConfig = {
	-- Why 72-50? see https://stackoverflow.com/q/2290016/22114136
	commitMaxLen = 72,
	smallCommitMaxLen = 50,

	-- when conforming the commit message popup with an empty message, 
	-- fill in this message. (Set to `false` to disallow empty commit messages.)
	emptyCommitMsgFillIn = "squash", -- string|false

	-- deny commit messages without a conventinal commit keyword
	enforceConvCommits = {
		enabled = true,
		keywords = { 
			"chore", "build", "test", "fix", "feat", "refactor", "perf", 
			"style", "revert", "ci", "docs", "break", "improv",
		},
	},
	-- icons for the issue/PR search
	issueIcons = {
		closedIssue = "🟣",
		openIssue = "🟢",
		openPR = "🟦",
		mergedPR = "🟨",
		closedPR = "🟥",
	},

	-- confirmation sounds on finished async operations (like push)
	confirmationSoundsOnMacOs = true,
}
```

## Credits
<!-- vale Google.FirstPerson = NO -->
__About Me__  
In my day job, I am a sociologist studying the social mechanisms underlying the digital economy. For my PhD project, I investigate the governance of the app economy and how software ecosystems manage the tension between innovation and compatibility. If you are interested in this subject, feel free to get in touch.

__Blog__  
I also occasionally blog about vim: [Nano Tips for Vim](https://nanotipsforvim.prose.sh)

__Profiles__  
- [reddit](https://www.reddit.com/user/pseudometapseudo)
- [Discord](https://discordapp.com/users/462774483044794368/)
- [Academic Website](https://chris-grieser.de/)
- [Twitter](https://twitter.com/pseudo_meta)
- [Mastodon](https://pkm.social/@pseudometa)
- [ResearchGate](https://www.researchgate.net/profile/Christopher-Grieser)
- [LinkedIn](https://www.linkedin.com/in/christopher-grieser-ba693b17a/)

__Buy Me a Coffee__  
<br>
<a href='https://ko-fi.com/Y8Y86SQ91' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://cdn.ko-fi.com/cdn/kofi1.png?v=3' border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>
