// Write the add-ons installed in a LibreWolf profile to librewolf/addons.json.
// Usage (from ~/dotfiles): bun librewolf/get-addons-list.js <profile directory>
// The profile directory is on about:profiles, for example
// "~/Library/Application Support/librewolf/Profiles/main.from-floorp".
// extensions.json lists the installed add-ons; the profile's addons.json is only a
// metadata cache and can still name removed add-ons.

const profile = process.argv[2]

if (!profile) {
  console.error("usage: bun librewolf/get-addons-list.js <profile directory>")
  process.exit(1)
}

const { addons } = JSON.parse(await Bun.file(`${profile}/extensions.json`).text())

const formatted = addons
  .filter((addon) => addon.location === "app-profile")
  .map((addon) => ({ id: addon.id, name: addon.defaultLocale.name }))
  .sort((a, b) => a.name.localeCompare(b.name))

await Bun.write("./librewolf/addons.json", JSON.stringify(formatted, null, 2) + "\n")
console.log(`✅ Wrote ${formatted.length} add-ons to librewolf/addons.json`)
