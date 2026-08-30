// MCShop recipe exporter for KubeJS 7 / Minecraft 1.21.1.
// Place in kubejs/server_scripts/mcshop_export.js.
// It exports the live server recipe registry without changing recipes.

ServerEvents.recipes(event => {
  const exported = []

  event.forEachRecipe({}, recipe => {
    try {
      exported.push({
        id: String(recipe.getId()),
        type: String(recipe.getType()),
        json: recipe.json
      })
    } catch (error) {
      console.error('[MCShop] Could not export one recipe: ' + error)
    }
  })

  JsonIO.write('mcshop_recipes.json', {
    generatedAt: new Date().toISOString(),
    recipeCount: exported.length,
    recipes: exported
  })

  console.log('[MCShop] Exported ' + exported.length + ' recipes to kubejs/mcshop_recipes.json')
})
