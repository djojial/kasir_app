import { BrowserMultiFormatReader } from 'https://esm.run/@zxing/library@0.20.0';

const activeScanners = new Map();
let nextId = 1;

function stopStream(video) {
  const stream = video.srcObject;
  if (stream && stream.getTracks) {
    stream.getTracks().forEach((t) => t.stop());
  }
  video.srcObject = null;
}

function waitForContainer(containerId, attempts = 20, delayMs = 50) {
  return new Promise((resolve) => {
    let count = 0;
    const tick = () => {
      const el = document.getElementById(containerId);
      if (el) return resolve(el);
      count += 1;
      if (count >= attempts) return resolve(null);
      setTimeout(tick, delayMs);
    };
    tick();
  });
}

window.startWebScanner = async function startWebScanner(containerId, onScan, onError) {
  try {
    if (!window.isSecureContext) {
      onError?.('Browser harus HTTPS untuk akses kamera.');
      return -1;
    }
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      onError?.('Browser tidak mendukung akses kamera.');
      return -1;
    }
    const container = await waitForContainer(containerId);
    if (!container) {
      onError?.('Container scanner tidak ditemukan.');
      return -1;
    }

    container.innerHTML = '';
    const video = document.createElement('video');
    video.setAttribute('playsinline', 'true');
    video.autoplay = true;
    video.muted = true;
    video.style.width = '100%';
    video.style.height = '100%';
    video.style.objectFit = 'cover';
    container.appendChild(video);

    const reader = new BrowserMultiFormatReader();
    const handleId = nextId++;
    activeScanners.set(handleId, { reader, video });

    const stream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: 'environment' },
      audio: false,
    });
    video.srcObject = stream;
    await video.play();

    reader.decodeFromVideoElementContinuously(video, (result) => {
      if (result) {
        const text = result.getText();
        onScan?.(text);
        window.stopWebScanner(handleId);
      }
    });

    return handleId;
  } catch (e) {
    const name = e && e.name ? e.name : 'UnknownError';
    const message = e && e.message ? e.message : 'Gagal membuka kamera web.';
    onError?.(`${name}: ${message}`);
    return -1;
  }
};

window.stopWebScanner = function stopWebScanner(handleId) {
  const data = activeScanners.get(handleId);
  if (!data) return;
  try {
    data.reader.reset();
  } catch (_) {}
  stopStream(data.video);
  if (data.video.parentElement) {
    data.video.parentElement.removeChild(data.video);
  }
  activeScanners.delete(handleId);
};

window.webScannerReady = true;
