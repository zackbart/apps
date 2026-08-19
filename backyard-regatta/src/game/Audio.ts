export class RaceAudio {
  private context: AudioContext | null = null;
  private master: GainNode | null = null;
  private wind: { gain: GainNode; filter: BiquadFilterNode } | null = null;
  private water: { gain: GainNode; filter: BiquadFilterNode } | null = null;
  private lastPerfect = false;

  async unlock(): Promise<void> {
    if (!this.context) this.createGraph();
    if (this.context?.state === 'suspended') await this.context.resume();
  }

  private createGraph(): void {
    this.context = new AudioContext();
    this.master = this.context.createGain();
    this.master.gain.value = 0.28;
    this.master.connect(this.context.destination);

    const buffer = this.context.createBuffer(1, this.context.sampleRate * 2, this.context.sampleRate);
    const channel = buffer.getChannelData(0);
    for (let index = 0; index < channel.length; index += 1) channel[index] = Math.random() * 2 - 1;

    const windSource = this.context.createBufferSource();
    windSource.buffer = buffer;
    windSource.loop = true;
    const windFilter = this.context.createBiquadFilter();
    windFilter.type = 'bandpass';
    windFilter.frequency.value = 640;
    windFilter.Q.value = 0.55;
    const windGain = this.context.createGain();
    windGain.gain.value = 0;
    windSource.connect(windFilter).connect(windGain).connect(this.master);
    windSource.start();
    this.wind = { gain: windGain, filter: windFilter };

    const waterSource = this.context.createBufferSource();
    waterSource.buffer = buffer;
    waterSource.loop = true;
    const waterFilter = this.context.createBiquadFilter();
    waterFilter.type = 'lowpass';
    waterFilter.frequency.value = 310;
    const waterGain = this.context.createGain();
    waterGain.gain.value = 0;
    waterSource.connect(waterFilter).connect(waterGain).connect(this.master);
    waterSource.start();
    this.water = { gain: waterGain, filter: waterFilter };
  }

  update(speedRatio: number, trimQuality: number, racing: boolean): void {
    if (!this.context || !this.wind || !this.water) return;
    const now = this.context.currentTime;
    const active = racing ? 1 : 0.22;
    const audibleSpeed = Math.pow(speedRatio, 0.72);
    this.wind.gain.gain.setTargetAtTime((0.03 + audibleSpeed * 0.15) * active, now, 0.1);
    this.wind.filter.frequency.setTargetAtTime(480 + audibleSpeed * 1120, now, 0.12);
    this.water.gain.gain.setTargetAtTime((0.024 + audibleSpeed * 0.19) * active, now, 0.07);
    this.water.filter.frequency.setTargetAtTime(260 + audibleSpeed * 1080, now, 0.08);

    const perfect = trimQuality > 0.985 && speedRatio > 0.35 && racing;
    if (perfect && !this.lastPerfect) this.tick();
    this.lastPerfect = perfect;
  }

  countdown(value: number): void {
    this.tone(value === 0 ? 660 : 340 + (3 - value) * 55, value === 0 ? 0.18 : 0.1, value === 0 ? 0.2 : 0.11, 'square');
  }

  gate(): void {
    this.tone(740, 0.07, 0.09, 'sine', 940);
  }

  impact(strength = 1): void {
    if (!this.context || !this.master) return;
    const oscillator = this.context.createOscillator();
    const gain = this.context.createGain();
    oscillator.type = 'triangle';
    oscillator.frequency.setValueAtTime(105, this.context.currentTime);
    oscillator.frequency.exponentialRampToValueAtTime(48, this.context.currentTime + 0.18);
    gain.gain.setValueAtTime(0.18 * strength, this.context.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, this.context.currentTime + 0.2);
    oscillator.connect(gain).connect(this.master);
    oscillator.start();
    oscillator.stop(this.context.currentTime + 0.22);
  }

  finish(place: number): void {
    const notes = place === 1 ? [523, 659, 784, 1047] : [440, 554, 659];
    notes.forEach((frequency, index) => {
      window.setTimeout(() => this.tone(frequency, 0.18, 0.1, 'triangle'), index * 115);
    });
  }

  private tick(): void {
    this.tone(1080, 0.035, 0.025, 'sine', 1340);
  }

  private tone(frequency: number, duration: number, volume: number, type: OscillatorType, endFrequency = frequency): void {
    if (!this.context || !this.master) return;
    const oscillator = this.context.createOscillator();
    const gain = this.context.createGain();
    oscillator.type = type;
    oscillator.frequency.setValueAtTime(frequency, this.context.currentTime);
    oscillator.frequency.exponentialRampToValueAtTime(endFrequency, this.context.currentTime + duration);
    gain.gain.setValueAtTime(volume, this.context.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, this.context.currentTime + duration);
    oscillator.connect(gain).connect(this.master);
    oscillator.start();
    oscillator.stop(this.context.currentTime + duration + 0.02);
  }
}
