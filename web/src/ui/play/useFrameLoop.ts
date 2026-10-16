import { useEffect, useRef, useState } from "preact/hooks";

/**
 * Calls `step(dt)` every animation frame while `running`, then re-renders.
 * Games keep their moving objects in a ref and mutate them in `step`.
 */
export function useFrameLoop(running: boolean, step: (dt: number, now: number) => void): void {
  const stepRef = useRef(step);
  stepRef.current = step;
  const [, setTick] = useState(0);

  useEffect(() => {
    if (!running) return;
    let frame = 0;
    let last = performance.now();
    const loop = (now: number) => {
      const dt = Math.min(0.1, (now - last) / 1000); // keeps pace on slow devices, no jumps after tab switches
      last = now;
      stepRef.current(dt, now);
      setTick((t) => (t + 1) % 1_000_000);
      frame = requestAnimationFrame(loop);
    };
    frame = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(frame);
  }, [running]);
}
