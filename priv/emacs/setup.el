;;; SETUP FILE FOR EMACS
(defun app-rel (subdir)
  (let ((app-root (expand-file-name
                    (concat (file-name-as-directory default-directory)
                            "../../"))))
    (expand-file-name (concat (file-name-as-directory app-root)
                              subdir))))

(setq erlang-compile-outdir (app-rel "ebin"))
(setq erlang-compile-includedir (app-rel "include"))
(setq inferior-erlang-machine-options `("-args_file" ,(app-rel "etc/vm.args")
                                        "-pa" ,(app-rel "ebin")))
(setq erlang-compile-extra-opts (list (cons 'i (app-rel "include"))
                                      'debug_info))



