;;; -*- lexical-binding: t; -*-

(require 'ert)
(require 'pdf-view)

(defconst pdf-view-midnight-test--pdf
  (expand-file-name "test.pdf" (file-name-directory load-file-name)))

(ert-deftest pdf-view-midnight-survives-document-and-server-close ()
  "Render the same midnight image after closing its server state."
  (let ((pdf-info-restart-process-p t))
    (unwind-protect
        (with-temp-buffer
          (setq buffer-file-name pdf-view-midnight-test--pdf
                major-mode 'pdf-view-mode)
          (setq-local pdf-view-midnight-colors '("white" . "black"))
          ;; Only the display requires a graphical Emacs.  Use the real
          ;; mode command and epdfinfo renderer throughout this test.
          (cl-letf (((symbol-function 'pdf-view-redisplay) #'ignore))
            (let ((plain (pdf-info-renderpage 1 200)))
              (pdf-view-midnight-minor-mode 1)
              (let ((midnight (pdf-info-renderpage 1 200)))
                (should-not (equal plain midnight))
                ;; Another buffer closing the same file also loses colors.
                (with-temp-buffer
                  (pdf-info-close pdf-view-midnight-test--pdf))
                (should (equal midnight (pdf-info-renderpage 1 200)))
                (pdf-info-quit)
                (should (equal midnight (pdf-info-renderpage 1 200)))
                (pdf-view-midnight-minor-mode -1)
                (should (equal plain (pdf-info-renderpage 1 200)))))))
      (pdf-info-quit))))

(ert-deftest pdf-view-midnight-asynchronous-render-and-explicit-target ()
  "Use the target buffer's colors and reserve its callback for the image."
  (let ((pdf-info-restart-process-p t))
    (unwind-protect
        (with-temp-buffer
          (setq buffer-file-name pdf-view-midnight-test--pdf
                major-mode 'pdf-view-mode)
          (cl-letf (((symbol-function 'pdf-view-redisplay) #'ignore))
            (pdf-view-midnight-minor-mode 1))
          (let ((target (current-buffer))
                (expected (pdf-info-renderpage 1 200))
                responses)
            (pdf-info-quit)
            (with-temp-buffer
              (let ((pdf-info-asynchronous
                     (lambda (status data) (push (cons status data) responses))))
                (pdf-info-renderpage 1 200 target))
              (let ((deadline (+ (float-time) 5)))
                (while (and (null responses) (< (float-time) deadline))
                  (accept-process-output nil 0.01)))
              (should (= (length responses) 1))
              (should-not (caar responses))
              (should (equal expected (cdar responses))))))
      (pdf-info-quit))))
