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

function stopTracksFromStream(stream) {
  if (!stream || !stream.getTracks) return;
  stream.getTracks().forEach((track) => {
    try {
      track.stop();
    } catch (_) {}
  });
}

async function findBackCameraDeviceId() {
  if (!navigator.mediaDevices || !navigator.mediaDevices.enumerateDevices) {
    return null;
  }
  try {
    const devices = await navigator.mediaDevices.enumerateDevices();
    const cameras = devices.filter((d) => d.kind === 'videoinput');
    if (!cameras.length) return null;
    const backCamera = cameras.find((camera) =>
      /back|rear|environment/i.test(camera.label || '')
    );
    const selected = backCamera || cameras[cameras.length - 1];
    return selected.deviceId || null;
  } catch (_) {
    return null;
  }
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

  // First pass: try direct constraints.
  let lastError = null;
  for (const constraints of candidates) {
    try {
      return await navigator.mediaDevices.getUserMedia(constraints);
    } catch (error) {
      lastError = error;
    }
  }

  // Second pass: request generic camera, then pin to the detected back camera.
  let warmupStream = null;
  try {
    warmupStream = await navigator.mediaDevices.getUserMedia({
      video: true,
      audio: false,
    });
    const backDeviceId = await findBackCameraDeviceId();
    if (backDeviceId) {
      try {
        const backStream = await navigator.mediaDevices.getUserMedia({
          video: {
            deviceId: { exact: backDeviceId },
            width: { ideal: 1920 },
            height: { ideal: 1080 },
          },
          audio: false,
        });
        stopTracksFromStream(warmupStream);
        return backStream;
      } catch (error) {
        lastError = error;
      }
    }
    return warmupStream;
  } catch (error) {
    lastError = error;
    stopTracksFromStream(warmupStream);
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
    if (capabilities.torch === true) {
      // Keep torch off by default; explicitly setting false helps some devices
      // avoid toggling unstable camera modes.
      advanced.push({ torch: false });
    }
    if (advanced.length > 0) {
      await track.applyConstraints({ advanced });
    }
  } catch (_) {
    // Ignore unsupported tuning constraints.
  }
}

function extractRawValue(result) {
  const raw = result && result.rawValue != null ? result.rawValue : '';
  return String(raw).trim();
}

async function createNativeDetector() {
  const Detector = window.BarcodeDetector;
  if (!Detector) return null;
  const preferredFormats = [
    'ean_13',
    'ean_8',
    'upc_a',
    'upc_e',
    'code_128',
    'code_39',
    'itf',
    'codabar',
    'qr_code',
  ];

  try {
    if (typeof Detector.getSupportedFormats === 'function') {
      const supported = await Detector.getSupportedFormats();
      const selected = preferredFormats.filter((f) => supported.includes(f));
      if (selected.length > 0) {
        return new Detector({ formats: selected });
      }
    }
    return new Detector();
  } catch (_) {
    try {
      return new Detector();
    } catch (_) {
      return null;
    }
  }
}

async function startNativeDetectorLoop(video, onDetected) {
  const detector = await createNativeDetector();
  if (!detector) return null;

  let active = true;
  let busy = false;

  const tick = async () => {
    if (!active) return;
    if (!video.videoWidth || !video.videoHeight || busy) {
      requestAnimationFrame(tick);
      return;
    }

    busy = true;
    try {
      const results = await detector.detect(video);
      if (Array.isArray(results)) {
        for (const result of results) {
          const value = extractRawValue(result);
          if (value) {
            onDetected(value);
            active = false;
            break;
          }
        }
      }
    } catch (_) {
      // Ignore transient detection errors.
    } finally {
      busy = false;
    }

    if (active) {
      requestAnimationFrame(tick);
    }
  };

  requestAnimationFrame(tick);
  return () => {
    active = false;
  };
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
    // Fill viewport to keep barcode pixels large enough for detection.
    video.style.objectFit = 'cover';
    container.appendChild(video);

    const hints = buildDecodeHints();
    const reader = new BrowserMultiFormatReader(hints, 200);
    const handleId = nextId++;
    const scannerState = {
      reader,
      video,
      stopped: false,
      stopNativeLoop: null,
    };
    activeScanners.set(handleId, scannerState);

    const stream = await openPreferredCameraStream();
    video.srcObject = stream;
    await video.play();
    await applyTrackTuning(stream);

    const emitDetected = (value) => {
      const text = String(value ?? '').trim();
      if (!text || scannerState.stopped) return;
      scannerState.stopped = true;
      onScan?.(text);
      window.stopWebScanner(handleId);
    };

    scannerState.stopNativeLoop = await startNativeDetectorLoop(
      video,
      emitDetected
    );

    reader.decodeFromVideoElementContinuously(video, (result) => {
      if (!result || scannerState.stopped) return;
      const text = result.getText ? result.getText() : '';
      emitDetected(text);
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
  data.stopped = true;
  if (typeof data.stopNativeLoop === 'function') {
    try {
      data.stopNativeLoop();
    } catch (_) {}
  }
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
