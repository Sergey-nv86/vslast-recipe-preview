(function () {
  'use strict';

  let workerPromise = null;

  async function getWorker() {
    if (!window.Tesseract) {
      throw new Error('Библиотека Tesseract.js не загрузилась.');
    }

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

  window.vslastRecipeOcr = async function (imagesJson) {
    const images = JSON.parse(imagesJson);
    if (!Array.isArray(images) || images.length < 1 || images.length > 8) {
      throw new Error('Ожидается от 1 до 8 фотографий.');
    }

    const worker = await getWorker();
    const pages = [];

    for (let index = 0; index < images.length; index += 1) {
      const image = images[index];
      if (typeof image !== 'string' || !image.startsWith('data:image/')) {
        throw new Error('Некорректный формат фотографии №' + (index + 1));
      }

      const result = await worker.recognize(image);
      const text = (result.data.text || '').trim();
      pages.push('Страница ' + (index + 1) + '\n' + text);
    }

    return pages.join('\n\n');
  };
})();
