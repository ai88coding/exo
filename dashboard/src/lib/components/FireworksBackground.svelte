<script lang="ts">
  import { onMount, onDestroy } from "svelte";

  let canvas: HTMLCanvasElement | undefined = $state();

  const COLORS = [
    "#00ff88",  // neon green
    "#39ff14",  // bright neon green
    "#ff00ff",  // magenta
    "#00ffff",  // cyan
    "#ffff00",  // yellow
    "#ff6600",  // orange
    "#ff0044",  // red-pink
    "#aa44ff",  // purple
    "#00ccff",  // sky blue
    "#ffaa00",  // gold
    "#ff88cc",  // pink
    "#7fff00",  // chartreuse
  ];

  interface Particle {
    x: number;
    y: number;
    vx: number;
    vy: number;
    color: string;
    size: number;
    alpha: number;
    decay: number;
    trail: { x: number; y: number }[];
  }

  interface Burst {
    particles: Particle[];
  }

  interface Rocket {
    x: number;
    y: number;
    vx: number;
    targetY: number;
    trail: { x: number; y: number }[];
  }

  let rockets: Rocket[] = [];
  let bursts: Burst[] = [];
  let lastSpawn = 0;
  let spawnInterval = 2000;
  let rafId = 0;
  let ctx: CanvasRenderingContext2D | null = null;

  function createRocket(): Rocket {
    const x = Math.random() * window.innerWidth;
    const targetY = 60 + Math.random() * (window.innerHeight * 0.35);
    return {
      x,
      y: window.innerHeight + 10,
      vx: (Math.random() - 0.5) * 0.8,
      targetY,
      trail: [],
    };
  }

  function createBurst(x: number, y: number): Burst {
    const count = 30 + Math.floor(Math.random() * 25);
    const particles: Particle[] = [];
    for (let i = 0; i < count; i++) {
      const angle = Math.random() * Math.PI * 2;
      const speed = 1 + Math.random() * 3;
      const colorIdx = Math.floor(Math.random() * COLORS.length);
      particles.push({
        x,
        y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        color: COLORS[colorIdx],
        size: 2 + Math.random() * 3,
        alpha: 1,
        decay: 0.006 + Math.random() * 0.010,
        trail: [],
      });
    }
    return { particles };
  }

  function update() {
    for (let i = rockets.length - 1; i >= 0; i--) {
      const r = rockets[i];
      r.y -= 2.2 + Math.random() * 0.8;
      r.x += r.vx;
      r.trail.push({ x: r.x, y: r.y });
      if (r.trail.length > 12) r.trail.shift();
      if (r.y <= r.targetY) {
        bursts.push(createBurst(r.x, r.y));
        rockets.splice(i, 1);
      }
    }

    for (let i = bursts.length - 1; i >= 0; i--) {
      const b = bursts[i];
      let alive = false;
      for (const p of b.particles) {
        if (p.alpha <= 0) continue;
        alive = true;
        p.trail.push({ x: p.x, y: p.y });
        if (p.trail.length > 6) p.trail.shift();
        p.x += p.vx;
        p.vy += 0.03;
        p.y += p.vy;
        p.vx *= 0.995;
        p.vy *= 0.995;
        p.alpha -= p.decay;
      }
      if (!alive) bursts.splice(i, 1);
    }
  }

  function draw() {
    if (!ctx || !canvas) return;
    ctx.clearRect(0, 0, window.innerWidth, window.innerHeight);

    for (const r of rockets) {
      for (let i = 0; i < r.trail.length; i++) {
        const t = r.trail[i];
        const a = (i / r.trail.length) * 0.6;
        ctx.beginPath();
        ctx.arc(t.x, t.y, 1.5, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(255,255,200,${a})`;
        ctx.fill();
      }
      ctx.beginPath();
      ctx.arc(r.x, r.y, 2.5, 0, Math.PI * 2);
      ctx.fillStyle = "#ffffff";
      ctx.fill();
    }

    for (const b of bursts) {
      for (const p of b.particles) {
        if (p.alpha <= 0) continue;
        // trail
        for (let i = 0; i < p.trail.length; i++) {
          const t = p.trail[i];
          const ta = (i / p.trail.length) * p.alpha * 0.5;
          ctx.beginPath();
          ctx.arc(t.x, t.y, p.size * 0.5, 0, Math.PI * 2);
          ctx.fillStyle = p.color;
          ctx.globalAlpha = ta;
          ctx.fill();
        }
        ctx.globalAlpha = p.alpha;
        // glow
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size * 2, 0, Math.PI * 2);
        ctx.fillStyle = p.color;
        ctx.globalAlpha = p.alpha * 0.2;
        ctx.fill();
        // core
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
        ctx.fillStyle = p.color;
        ctx.globalAlpha = p.alpha;
        ctx.fill();
        ctx.globalAlpha = 1;
      }
    }
  }

  function tick() {
    const now = performance.now();
    if (now - lastSpawn > spawnInterval) {
      lastSpawn = now;
      spawnInterval = 2000 + Math.random() * 4000;
      const count = 1 + Math.floor(Math.random() * 2);
      for (let i = 0; i < count; i++) {
        spawnFirework();
      }
    }
    update();
    draw();
    rafId = requestAnimationFrame(tick);
  }

  function resize() {
    if (!canvas || !ctx) return;
    const dpr = window.devicePixelRatio || 1;
    canvas.width = window.innerWidth * dpr;
    canvas.height = window.innerHeight * dpr;
    canvas.style.width = window.innerWidth + "px";
    canvas.style.height = window.innerHeight + "px";
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  onMount(() => {
    if (!canvas) return;
    ctx = canvas.getContext("2d");
    if (!ctx) return;
    resize();
    window.addEventListener("resize", resize);
    lastSpawn = performance.now();
    setTimeout(() => spawnFirework(), 400);
    setTimeout(() => spawnFirework(), 1200);
    rafId = requestAnimationFrame(tick);
  });

  onDestroy(() => {
    cancelAnimationFrame(rafId);
    window.removeEventListener("resize", resize);
  });

  function spawnFirework() {
    rockets.push(createRocket());
  }
</script>

<canvas
  bind:this={canvas}
  class="fixed inset-0 pointer-events-none"
  style="z-index: 10; display: block; width: 100vw; height: 100vh; background: transparent;"
></canvas>
