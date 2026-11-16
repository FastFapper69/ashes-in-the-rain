// Sprite sheets and background layers come from PNG files in /assets. Until a file is there, the game
// falls back to the placeholder it can draw itself, so art can be dropped in one sheet at a time.
class AssetLoader {
  constructor(base, names) { this.base = base; this.names = names; this.img = {}; this.state = {}; this.onchange = null; }
  load() {
    for (const n of this.names) {
      const im = new Image(); this.state[n] = 'loading';
      im.onload = () => { this.img[n] = im; this.state[n] = 'ok'; if (this.onchange) this.onchange(n); };
      im.onerror = () => { this.state[n] = 'missing'; };
      im.src = this.base + n + '.png';
    }
  }
  get(n) { return this.img[n] || null; }
}
// frame grid shared by every character sheet
const SPR = { F: 512, PPM: 200, FEET_X: 256, FEET_Y: 448, ARM_W: 512, ARM_H: 256, ARM_PX: 128, ARM_PY: 128,
  BAKED_ARMS: true }; // the current sheets have the gun arms drawn into the body frames, so no separate arm sprite is turned to the aim
const Assets = new AssetLoader('assets/', ['player_sheet', 'enemy_sheet', 'arms_sheet', 'props_sheet', 'fx_sheet', 'bg_manhattan_far', 'bg_rooftop_mid', 'bg_street_wall']);
