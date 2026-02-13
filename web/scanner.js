import {
  BrowserMultiFormatReader,
  DecodeHintType,
  BarcodeFormat,
} from 'https://esm.run/@zxing/library@0.20.0';

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

async function openPreferredCameraStream() {
  const candidates = [
    {
      video: {
        facingMode: { exact: 'environment' },
        width: { ideal: 1920 },
        height: { ideal: 1080 },
      },
      audio: false,
    },
    {
      video: {
        facingMode: { ideal: 'environment' },
        width: { ideal: 1920 },
        height: { ideal: 1080 },
      },
      audio: false,
    },
    {
      video: {
        facingMode: { ideal: 'user' },
        width: { ideal: 1920 },
        height: { ideal: 1080 },
      },
      audio: false,
    },
    { video: true, audio: false },
  ];

  let lastError = null;
  for (const constraints of candidates) {
    try {
      return await navigator.mediaDevices.getUserMedia(constraints);
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError ?? new Error('Tidak bisa membuka kamera.');
}

function buildDecodeHints() {
  const hints = new Map();
  hints.set(DecodeHintType.TRY_HARDER, true);
  hints.set(DecodeHintType.POSSIBLE_FORMATS, [
    BarcodeFormat.EAN_13,
    BarcodeFormat.EAN_8,
    BarcodeFormat.UPC_A,
    BarcodeFormat.UPC_E,
    BarcodeFormat.CODE_128,
    BarcodeFormat.CODE_39,
    BarcodeFormat.ITF,
    BarcodeFormat.CODABAR,
    BarcodeFormat.QR_CODE,
  ]);
  return hints;
}

async function applyTrackTuning(stream) {
  const track = stream.getVideoTracks && stream.getVideoTracks()[0];
  if (!track || !track.applyConstraints) return;
  try {
    const capabilities = track.getCapabilities ? track.getCapabilities() : {};
    const advanced = [];
    if (
      capabilities.focusMode &&
      Array.isArray(capabilities.focusMode) &&
      capabilities.focusMode.includes('continuous')
    ) {
      advanced.push({ focusMode: 'continuous' });
    }
    if (advanced.length > 0) {
      await track.applyConstraints({ advanced });
    }
  } catch (_) {
    // Ignore unsupported tuning constraints.
  }
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
    // Preserve full frame so barcode edges are not cropped.
    video.style.objectFit = 'contain';
    container.appendChild(video);

    const hints = buildDecodeHints();
    const reader = new BrowserMultiFormatReader(hints, 200);
    const handleId = nextId++;
    activeScanners.set(handleId, { reader, video });

    const stream = await openPreferredCameraStream();
    video.srcObject = stream;
    await video.play();
    await applyTrackTuning(stream);

    reader.decodeFromVideoElementContinuously(video, (result) => {
      if (result) {
        const text = result.getText ? result.getText() : '';
        if (text && text.trim()) {
          onScan?.(text.trim());
          window.stopWebScanner(handleId);
        }
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
