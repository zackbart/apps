import './style.css';
import { Regatta } from './game/Regatta';

const container = document.querySelector<HTMLElement>('#game');
if (!container) throw new Error('Game container not found.');

const game = new Regatta(container);
game.run();
