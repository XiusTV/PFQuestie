# How to Push to GitHub

## 🚀 Ready to Push!

Everything is prepared and ready. Here's how to push to your GitHub repository:

### Step 1: Set Remote (If Not Already Set)

```bash
cd "D:\Games\Ascension\Live\Interface\PFQuest-Wotlk"
git remote add origin https://github.com/XiusTV/PFQuest-Wotlk.git
```

### Step 2: Push to GitHub

```bash
git branch -M main
git push -u origin main
```

### Step 3: Verify on GitHub

Visit: https://github.com/XiusTV/PFQuest-Wotlk

You should see:
- ✅ README.md displayed on main page
- ✅ CHANGELOG.md visible
- ✅ Both addon folders (pfQuest-wotlk and pfQuest-bronzebeard)
- ✅ Professional project layout

---

## 📁 Repository Structure

```
PFQuest-Wotlk/
├── README.md                        ← Main project page
├── CHANGELOG.md                     ← Version history
├── PUSH_TO_GITHUB.md               ← This file
├── LICENSE                         ← License file
├── .gitignore                      ← Git ignore rules
├── pfQuest-wotlk/                  ← Core WotLK addon
│   ├── pfQuest-wotlk.toc
│   ├── browser.lua
│   ├── database.lua
│   ├── questcapture.lua
│   ├── db/                         ← Database files
│   └── ...                         ← All addon files
└── pfQuest-bronzebeard/            ← Bronzebeard addon
    ├── pfQuest-bronzebeard.toc
    ├── pfQuest-bronzebeard.lua
    ├── db/                         ← Database files
    └── ...                         ← All addon files
```

---

## ✅ What's Included

### Files Ready for Push:
- ✅ Both addon folders (pfQuest-wotlk and pfQuest-bronzebeard)
- ✅ README.md (GitHub-formatted, unified documentation)
- ✅ CHANGELOG.md (version history)
- ✅ LICENSE (MIT + credits)
- ✅ .gitignore (proper exclusions)
- ✅ Git commit created
- ✅ Ready for `git push`

### What Users Will See:
1. **Main page**: Professional README with unified documentation
2. **Two addon folders**: pfQuest-wotlk and pfQuest-bronzebeard
3. **Documentation**: Changelog, installation guide, license
4. **Clean structure**: Organized and easy to navigate

---

## 🎯 Commands Summary

```bash
# Navigate to repo
cd "D:\Games\Ascension\Live\Interface\PFQuest-Wotlk"

# Add remote (if not already added)
git remote add origin https://github.com/XiusTV/PFQuest-Wotlk.git

# Push to GitHub
git branch -M main
git push -u origin main
```

---

## 📝 After Pushing

### Update Your Project Links

Add PFQuest to your other projects' READMEs:

**In Modern-TSM-335 README**:
```markdown
## Related Projects
- [PFQuest-WotLK](https://github.com/XiusTV/PFQuest-Wotlk) - Unified quest database suite
- [ElvUI VibeUI](https://github.com/XiusTV/Elvui-VibeUI) - Modern ElvUI configuration
```

**In ElvUI README** (if you have one):
```markdown
## Related Projects
- [PFQuest-WotLK](https://github.com/XiusTV/PFQuest-Wotlk) - Quest database with capture system
- [Modern TSM](https://github.com/XiusTV/Modern-TSM-335) - Performance-optimized TSM
```

### GitHub Repository Settings

After pushing, configure:
1. **Description**: "Unified quest database suite for WoW 3.3.5 with automated quest capture - includes pfQuest-wotlk and pfQuest-bronzebeard"
2. **Topics**: Add tags like `wow`, `wotlk`, `pfquest`, `addon`, `world-of-warcraft`, `quest-helper`, `database`
3. **About**: Add website link if you have one

---

## 🔄 Workflow for Future Updates

### Your Setup (Similar to TSM):

**Working Folders** (in AddOns - for testing/editing):
- `Interface\AddOns\pfQuest-wotlk\` ← Make changes here
- `Interface\AddOns\pfQuest-bronzebeard\` ← Make changes here

**GitHub Push Folder** (in Interface - for pushing):
- `Interface\PFQuest-Wotlk\` ← Push from here

### When You Want to Push Updates:

```bash
# 1. Copy updated files from AddOns to PFQuest-Wotlk folder
cd "D:\Games\Ascension\Live\Interface"
robocopy "AddOns\pfQuest-wotlk" "PFQuest-Wotlk\pfQuest-wotlk" /E /XO
robocopy "AddOns\pfQuest-bronzebeard" "PFQuest-Wotlk\pfQuest-bronzebeard" /E /XO

# 2. Navigate to push folder
cd "PFQuest-Wotlk"

# 3. Stage and commit changes
git add .
git commit -m "Your commit message here"

# 4. Push to GitHub
git push
```

---

## 💡 Tips

### Only Push When Ready
- Test changes in AddOns folder first
- When satisfied, copy to PFQuest-Wotlk folder
- Review changes with `git status` and `git diff`
- Then commit and push

### Meaningful Commit Messages
Examples:
- `git commit -m "Add quest capture for Northrend zones"`
- `git commit -m "Fix database lookup performance issue"`
- `git commit -m "Update README with new capture features"`

### Keep Working Folder Separate
- **Never** edit files directly in PFQuest-Wotlk folder
- Always work in AddOns folder
- Copy to PFQuest-Wotlk only when ready to push
- This prevents accidentally pushing WIP changes

---

## 🎉 You're All Set!

Once you push, anyone can:

```bash
git clone https://github.com/XiusTV/PFQuest-Wotlk.git
```

And get both addons in one unified repository! 🚀

---

**Repository**: https://github.com/XiusTV/PFQuest-Wotlk  
**Status**: ✅ Ready to Push  
**Commit**: ✅ Created  
**Files**: ✅ All Staged

