(function () {
  'use strict';

  let workerPromise = null;
  const MAX_IMAGE_WIDTH = 2600;
  const TARGET_IMAGE_WIDTH = 1900;

  async function getWorker() {
    if (!window.Tesseract) throw new Error('Библиотека Tesseract.js не загрузилась.');
    if (!workerPromise) {
      workerPromise = window.Tesseract.createWorker('rus', 1, {
        workerPath: 'https://cdn.jsdelivr.net/npm/tesseract.js@5.1.1/dist/worker.min.js',
        langPath: 'https://tessdata.projectnaptha.com/4.0.0',
        corePath: 'https://cdn.jsdelivr.net/npm/tesseract.js-core@5.1.1',
        gzip: true,
        logger: function (message) {
          if (message && message.status) {
            console.info('[Recipe OCR]', message.status,
              Math.round((message.progress || 0) * 100) + '%');
          }
        }
      }).catch(function (error) {
        workerPromise = null;
        throw error;
      });
    }
    return workerPromise;
  }

  function loadImage(dataUrl) {
    return new Promise(function (resolve, reject) {
      const image = new Image();
      image.onload = function () { resolve(image); };
      image.onerror = function () {
        reject(new Error('Не удалось открыть фотографию для обработки.'));
      };
      image.src = dataUrl;
    });
  }

  function makeCanvas(image, threshold) {
    const sourceWidth = image.naturalWidth || image.width;
    const sourceHeight = image.naturalHeight || image.height;
    if (!sourceWidth || !sourceHeight) {
      throw new Error('У фотографии не удалось определить размер.');
    }

    let scale = sourceWidth < TARGET_IMAGE_WIDTH
      ? Math.min(TARGET_IMAGE_WIDTH / sourceWidth, 2.5)
      : 1;
    scale = Math.min(scale, MAX_IMAGE_WIDTH / sourceWidth);

    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(sourceWidth * scale));
    canvas.height = Math.max(1, Math.round(sourceHeight * scale));
    const context = canvas.getContext('2d', { willReadFrequently: true });
    if (!context) throw new Error('Браузер не смог подготовить фотографию.');

    context.imageSmoothingEnabled = true;
    context.imageSmoothingQuality = 'high';
    context.filter = 'grayscale(1) contrast(1.22) brightness(1.02)';
    context.drawImage(image, 0, 0, canvas.width, canvas.height);
    context.filter = 'none';

    if (threshold) {
      const frame = context.getImageData(0, 0, canvas.width, canvas.height);
      const pixels = frame.data;
      const histogram = new Array(256).fill(0);
      for (let i = 0; i < pixels.length; i += 4) histogram[pixels[i]] += 1;

      const total = canvas.width * canvas.height;
      let sum = 0;
      for (let i = 0; i < 256; i += 1) sum += i * histogram[i];

      let sumBackground = 0;
      let weightBackground = 0;
      let bestVariance = -1;
      let cutoff = 160;
      for (let i = 0; i < 256; i += 1) {
        weightBackground += histogram[i];
        if (!weightBackground) continue;
        const weightForeground = total - weightBackground;
        if (!weightForeground) break;
        sumBackground += i * histogram[i];
        const meanBackground = sumBackground / weightBackground;
        const meanForeground = (sum - sumBackground) / weightForeground;
        const variance = weightBackground * weightForeground *
          Math.pow(meanBackground - meanForeground, 2);
        if (variance > bestVariance) {
          bestVariance = variance;
          cutoff = i;
        }
      }

      for (let i = 0; i < pixels.length; i += 4) {
        const value = pixels[i] < cutoff ? 0 : 255;
        pixels[i] = value;
        pixels[i + 1] = value;
        pixels[i + 2] = value;
      }
      context.putImageData(frame, 0, 0);
    }
    return canvas.toDataURL('image/png');
  }

  function assess(result) {
    const text = (result.data.text || '').trim();
    const lines = text.split(/\r?\n/).filter(function (line) {
      return line.trim().length > 0;
    });
    const words = text.match(/[А-Яа-яЁёA-Za-z0-9]+/g) || [];
    const letters = text.match(/[А-Яа-яЁёA-Za-z]/g) || [];
    const suspicious = text.match(/[|~^]{2,}|[^А-Яа-яЁёA-Za-z0-9\s.,:;!?()/%+№°-]/g) || [];
    const confidence = Number(result.data.confidence) || 0;
    const density = words.length ? letters.length / words.length : 0;
    const penalty = Math.min(18, suspicious.length * 0.7);
    const structure = Math.min(8, lines.length * 0.12) +
      Math.min(8, words.length * 0.035) + Math.min(5, density * 1.5);
    return { text: text, score: confidence + structure - penalty, confidence: confidence };
  }

  async function recognizeWithMode(worker, image, mode) {
    await worker.setParameters({
      tessedit_pageseg_mode: String(mode),
      preserve_interword_spaces: '1'
    });
    return assess(await worker.recognize(image));
  }

  async function recognizePage(worker, dataUrl) {
    const image = await loadImage(dataUrl);
    const enhanced = makeCanvas(image, false);
    const modes = [3, 6, 11];
    let best = { text: '', score: -1, confidence: 0 };

    for (const mode of modes) {
      const candidate = await recognizeWithMode(worker, enhanced, mode);
      if (candidate.score > best.score) best = candidate;
    }

    if (best.confidence < 68 || best.text.length < 80) {
      const binary = makeCanvas(image, true);
      const candidate = await recognizeWithMode(worker, binary, 3);
      if (candidate.score > best.score) best = candidate;
    }
    return best.text;
  }

  window.vslastRecipeOcr = async function (imagesJson) {
    const images = JSON.parse(imagesJson);
    if (!Array.isArray(images) || images.length < 1 || images.length > 8) {
      throw new Error('Ожидается от 1 до 8 фотографий.');
    }
    for (let index = 0; index < images.length; index += 1) {
      if (typeof images[index] !== 'string' ||
          !images[index].startsWith('data:image/')) {
        throw new Error('Некорректный формат фотографии №' + (index + 1));
      }
    }

    const worker = await getWorker();
    const pages = [];
    try {
      for (let index = 0; index < images.length; index += 1) {
        const text = await recognizePage(worker, images[index]);
        pages.push('Страница ' + (index + 1) + '\n' + text);
      }
      return pages.join('\n\n');
    } finally {
      try {
        await worker.terminate();
      } finally {
        workerPromise = null;
      }
    }
  };
})();
