# ⚕ Leechcraft — Dynamic Bandaging

Bandaging in *Kingdom Come: Deliverance II* now grows with your **Scholarship**.  
The more you study, the more precise your bindings become. Early in the game, wounds demand far more cloth, but as your knowledge deepens, you learn to save precious bandages.  

> 💡 *Leechcraft V* matches the vanilla bandage efficiency, ensuring balance is preserved at max skill — yet there lies a long road before one’s hands earn such mastery.

---

## ✨ Features

- 📚 **Dynamic Bandaging** — bandage efficiency scales with your **Scholarship** skill.  
- 🎓 **Five tiers of buffs** (Leechcraft I–V), each with unique localization and icon.  
- 🛌 **Sleep/Wake integration** — buffs are refreshed every time you wake up.  
- ⚖️ **Immersive progression** — in early game you’ll need more bandages, adding challenge.  
- 🩹 Balance preserved — at max skill, bandages heal as effectively as vanilla.  
- 💡 “Stock up those bandages!”  

---

## 🔧 Technical Notes

- Implemented via a **scripted hook** into the sleep/wake cycle.  
- On wake (or load), the player’s **Scholarship level** is read directly from `player.soul:GetSkillLevel("scholarship")`.  
- A buff tier (I–V) is chosen and applied by UUID.  
- Buffs override earlier tiers to ensure only one is active.  
- The vanilla “Leechcraft Reset” perk buff was replaced with tiered scaling.  
- Uses **SkipTime UI listeners** and a retry-on-load system to ensure reliability.  

---

## 📸 Screenshots

*(to be added once your icons and captures are ready)*

---

## 📥 Installation

1. Extract the `Leechcraft` folder into your game’s `Mods/` directory.  
2. Ensure the mod is enabled in your `mod_order.txt`.  
3. Start the game, sleep once, and check your buff list for **Leechcraft I–V**.  

---

## 🧪 Testing & Reliability

- ✅ Buffs tested on **new saves** and **endgame saves**.  
- ✅ Tiers verified to apply correctly on wake and on reload.  
- ✅ Fail-safe retry logic ensures buffs apply even if the soul entity is late-spawned.  
- ⚠️ Known Quirk: On late saves, make sure the base **Leechcraft perk** appears learned — otherwise the UI may display oddly, but functionality still works.  

---

## 📜 Motivation

This mod began as a small tweak after discovering that **bandage ointment efficiency** was defined in the data.  
Originally intended as a simple nerf for *Veteran Hardcore*, the idea grew: instead of static values, why not make efficiency **dynamic and tied to learning**?  
Thus *Leechcraft* was born — a system where **knowledge itself heals**.

---

## 🛠 Compatibility

- Built and tested on **KCD2 (latest patch)**.  
- Not compatible with other mods that override the **Scholarship buff system** or **bandage efficiency parameters**.  
- Safe to add mid-playthrough.  

---

## 📄 License

MIT License — free to use, modify, and expand.  
Just credit **Leechcraft** if you build upon it.  

---

## 🙏 Credits

- Code & Design: *you*  
- Testing & Debugging: sleepless nights + way too many bandages  
- Special thanks to the KCD modding community  

---
