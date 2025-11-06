# Changelog

All notable changes to this project will be documented in this file.

---

## [1.0.0] - 2025-11-06

### Added
- **Unified Repository Structure**
  - Combined pfQuest-wotlk and pfQuest-bronzebeard into single repository
  - Organized folder structure for easy installation
  - Comprehensive unified README documentation

- **pfQuest-wotlk Features**
  - Automated quest capture system with live database injection
  - Performance optimizations (~70% CPU reduction)
  - Full Vanilla + TBC quest database
  - Multi-language support (enUS, deDE, frFR, esES, ruRU, zhCN, zhTW, koKR, ptBR)
  - Database browser with quest/item/NPC/object search
  - Map and minimap integration with spawn points
  - Quest tracking with HUD arrow
  - Lazy loading and efficient caching

- **pfQuest-bronzebeard Features**
  - Ascension Bronzebeard realm-specific quest data
  - Server-specific NPC spawn overrides
  - Custom quest locations for Bronzebeard
  - Automated quest capture for realm content
  - World map integration for Bronzebeard zones

- **Quest Capture System**
  - Automatic quest detection when accepting quests
  - Smart NPC tracking with accurate zone IDs
  - Objective tracking (kill/collect/explore)
  - Quest item source detection
  - Reward data capture
  - Export functionality for sharing captures
  - External merger tool for permanent database integration
  - Per-character capture history

### Changed
- Reorganized repository structure for unified distribution
- Updated documentation to cover both addons
- Standardized command structure across both addons

### Technical
- Repository structure mirrors TSM/ElvUI setup
- Working folders remain in AddOns for testing
- GitHub push folder in Interface for version control
- Robocopy-based update workflow

---

## Future Plans

### Planned Features
- Expanded Northrend (WotLK 70-80) quest database
- Community quest capture sharing system
- Enhanced capture UI with detailed statistics
- Cloud-sync for quest captures
- Better export/import tools

### In Development
- Additional Bronzebeard realm quests
- Performance improvements for large databases
- Enhanced map rendering
- Quest chain visualization

---

## Contributing

To contribute quest captures:
1. Complete quests with capture system active
2. Export captured data via `/pfquest capture export`
3. Submit exports via GitHub issues or pull requests
4. Help expand the database for the community!

---

**Maintainer**: XiusTV  
**Based on**: pfQuest by Shagu  
**License**: Same as original pfQuest project

