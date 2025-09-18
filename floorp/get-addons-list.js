const addonsPath = "" // addons.json path, something like this: "/Users/fjorn/Library/Application Support/Floorp/Profiles/e2ze8qve.default-release/addons.json"

if (!addonsPath) {
  console.error("addonsPath is not set")
  process.exit(1)
}

const constent = await Bun.file(addonsPath).text()

const addons = JSON.parse(constent).addons

const formatted = addons.map((addon) => {
  return {
    id: addon.id,
    name: addon.name,
  }
})

await Bun.write("./floorp/addons.json", JSON.stringify(formatted, null, 2))
