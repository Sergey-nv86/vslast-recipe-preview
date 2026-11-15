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

  function wordLineKey(word, index) {
    if (word.block_num !== undefined && word.par_num !== undefined &&
        word.line_num !== undefined) {
      return [word.block_num, word.par_num, word.line_num].join(':');
    }
    const box = word.bbox || {};
    return 'y:' + Math.round(((box.y0 || 0) + (box.y1 || 0)) / 2 / 12) +
      ':' + index;
  }

  function lineFromWords(words) {
    const sorted = words.slice().sort(function (a, b) {
      return (a.bbox.x0 || 0) - (b.bbox.x0 || 0);
    });
    const text = sorted.map(function (word) {
      return String(word.text || '').trim();
    }).filter(Boolean).join(' ');
    const boxes = sorted.map(function (word) { return word.bbox || {}; });
    return {
      text: text,
      x0: Math.min.apply(null, boxes.map(function (box) { return box.x0 || 0; })),
      x1: Math.max.apply(null, boxes.map(function (box) { return box.x1 || 0; })),
      y0: Math.min.apply(null, boxes.map(function (box) { return box.y0 || 0; })),
      y1: Math.max.apply(null, boxes.map(function (box) { return box.y1 || 0; }))
    };
  }

  // Rebuild reading order from word coordinates. In a two-column recipe,
  // read the left column top-to-bottom, then the right column, not row-by-row.
  function reconstructReadingOrder(result, pageWidth) {
    const words = (result.data && result.data.words) || [];
    if (!words.length) return (result.data && result.data.text) || '';

    const groups = new Map();
    words.forEach(function (word, index) {
      const key = wordLineKey(word, index);
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key).push(word);
    });

    const lines = Array.from(groups.values()).map(lineFromWords)
      .filter(function (line) { return line.text.length > 0; })
      .sort(function (a, b) {
        return a.y0 === b.y0 ? a.x0 - b.x0 : a.y0 - b.y0;
      });

    if (!lines.length) return (result.data && result.data.text) || '';

    // A wide heading or full-width instruction separates page bands.
    const spanning = lines.filter(function (line) {
      return line.x1 - line.x0 >= pageWidth * 0.58;
    });
    const ordered = [];
    let band = [];

    function flushBand() {
      if (!band.length) return;
      const left = [];
      const right = [];
      band.forEach(function (line) {
        const center = (line.x0 + line.x1) / 2;
        (center < pageWidth * 0.5 ? left : right).push(line);
      });
      const hasTwoColumns = left.length >= 2 && right.length >= 2 &&
        Math.abs(
          left.reduce(function (sum, line) {
            return sum + (line.x0 + line.x1) / 2;
          }, 0) / left.length -
          right.reduce(function (sum, line) {
            return sum + (line.x0 + line.x1) / 2;
          }, 0) / right.length
        ) > pageWidth * 0.2;

      if (hasTwoColumns) {
        left.sort(function (a, b) { return a.y0 - b.y0; });
        right.sort(function (a, b) { return a.y0 - b.y0; });
        ordered.push.apply(ordered, left);
        ordered.push.apply(ordered, right);
      } else {
        band.sort(function (a, b) {
          return a.y0 === b.y0 ? a.x0 - b.x0 : a.y0 - b.y0;
        });
        ordered.push.apply(ordered, band);
      }
      band = [];
    }

    lines.forEach(function (line) {
      if (spanning.indexOf(line) !== -1) {
        flushBand();
        ordered.push(line);
      } else {
        band.push(line);
      }
    });
    flushBand();

    return ordered.map(function (line) { return line.text; }).join('\n');
  }

  function normalizeOcrText(text) {
    return String(text || '')
      .replace(/\r/g, '')
      .replace(/([А-Яа-яЁё])- *\n *([а-яё])/g, '$1$2')
      .replace(/[ \t]+\n/g, '\n')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
  }

  function assess(result, pageWidth) {
    const text = normalizeOcrText(reconstructReadingOrder(result, pageWidth));
    const lines = text.split(/\n/).filter(function (line) {
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
    return {
      text: text,
      score: confidence + structure - penalty,
      confidence: confidence
    };
  }

  async function recognizeWithMode(worker, image, mode, pageWidth) {
    await worker.setParameters({
      tessedit_pageseg_mode: String(mode),
      preserve_interword_spaces: '1'
    });
    return assess(await worker.recognize(image), pageWidth);
  }

  async function recognizePage(worker, dataUrl) {
    const image = await loadImage(dataUrl);
    const sourceWidth = image.naturalWidth || image.width;
    let scale = sourceWidth < TARGET_IMAGE_WIDTH
      ? Math.min(TARGET_IMAGE_WIDTH / sourceWidth, 2.5)
      : 1;
    scale = Math.min(scale, MAX_IMAGE_WIDTH / sourceWidth);
    const processedWidth = Math.max(1, Math.round(sourceWidth * scale));
    const enhanced = makeCanvas(image, false);
    const modes = [3, 11, 6];
    let best = { text: '', score: -1, confidence: 0 };

    for (const mode of modes) {
      const candidate = await recognizeWithMode(
        worker, enhanced, mode, processedWidth
      );
      if (candidate.score > best.score) best = candidate;
    }

    if (best.confidence < 68 || best.text.length < 80) {
      const binary = makeCanvas(image, true);
      const candidate = await recognizeWithMode(worker, binary, 3, processedWidth);
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
