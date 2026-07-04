/* Tweaks panel — isolated React island that re-paints the vanilla page via CSS vars */
const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "accent": "#df521d",
  "paper": "warm",
  "grid": true
}/*EDITMODE-END*/;

const PAPER_TONES = {
  warm: { '--paper': '#f4f1ea', '--paper-2': '#ece7db', '--paper-3': '#e2dccd' },
  cool: { '--paper': '#eef1f3', '--paper-2': '#e4e9ec', '--paper-3': '#d6dde1' },
  bone: { '--paper': '#f6f4ef', '--paper-2': '#edeae2', '--paper-3': '#e1ddd2' }
};

function deepen(hex) {
  // darken ~12% for --signal-deep
  const n = parseInt(hex.slice(1), 16);
  let r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
  r = Math.round(r * 0.84); g = Math.round(g * 0.84); b = Math.round(b * 0.84);
  return '#' + [r, g, b].map((v) => v.toString(16).padStart(2, '0')).join('');
}

function TweaksApp() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);

  React.useEffect(() => {
    const root = document.documentElement;
    root.style.setProperty('--signal', t.accent);
    root.style.setProperty('--signal-deep', deepen(t.accent));
    const tone = PAPER_TONES[t.paper] || PAPER_TONES.warm;
    Object.entries(tone).forEach(([k, v]) => root.style.setProperty(k, v));
    document.body.classList.toggle('no-grid', !t.grid);
  }, [t.accent, t.paper, t.grid]);

  return (
    <TweaksPanel>
      <TweakSection label="Accent" />
      <TweakColor label="Signal color" value={t.accent}
        options={['#df521d', '#2f6f8f', '#2f7d54', '#b8402c', '#6a59c4']}
        onChange={(v) => setTweak('accent', v)} />
      <TweakSection label="Surface" />
      <TweakRadio label="Paper tone" value={t.paper}
        options={['warm', 'cool', 'bone']}
        onChange={(v) => setTweak('paper', v)} />
      <TweakToggle label="Blueprint grid" value={t.grid}
        onChange={(v) => setTweak('grid', v)} />
    </TweaksPanel>
  );
}

ReactDOM.createRoot(document.getElementById('tweaks-root')).render(<TweaksApp />);
