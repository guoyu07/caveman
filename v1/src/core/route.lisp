#|
  This file is a part of Caveman package.
  URL: http://github.com/fukamachi/caveman
  Copyright (c) 2011 Eitaro Fukamachi <e.arrows@gmail.com>

  Caveman is freely distributable under the LLGPL License.
|#

(in-package :cl-user)
(defpackage caveman.route
  (:use :cl
        :clack
        :cl-annot
        :cl-annot.doc)
  (:import-from :do-urlencode
                :urlencode)
  (:import-from :myway.rule
                :make-rule
                :rule-url-for)
  (:import-from :cl-annot.util
                :progn-form-last
                :definition-form-symbol
                :definition-form-type)
  (:import-from :caveman.app
                :add-route
                :lookup-route))
(in-package :caveman.route)

(cl-syntax:use-syntax :annot)

@export
(defannotation url (method url-rule form)
    (:arity 3)
  "Useful annotation to define actions.

Example:
  ;; for Function
  @url GET \"/login\"
  (defun login (req)
    ;; response
    )

  ;; for Clack Component
  @url GET \"/member/:id\"
  (defclass <member-profile> (<component>) ())
  (defmethod call ((this <member-profile>) req)
    ;; response
    )"
  `(progn
     (add-route ,(intern "*APP*" *package*)
                (url->routing-rule ,method ,url-rule ,form))
     ,form))



(progn
  @export
  (defmacro defroute (method url-rule form)
    "Recreation of @URL annotation in S-expression form"
    `(progn
       (add-route ,(intern "*APP*" *package*)
                  (url->routing-rule ,method ,url-rule ,form))
       ,form)))


@doc "
Convert action form into a routing rule, a list.

Example:
  ((member-profile #<url-rule> #'member-profile)
   (login-form #<url-rule> #'login-form))
"
@export
(defmacro url->routing-rule (method url-rule form)
  (let* ((last-form (progn-form-last form))
         (type (definition-form-type last-form))
         (symbol (definition-form-symbol last-form))
         (req (gensym "REQ")))
    `(list
      ',symbol
      (make-rule ,url-rule :method ,(intern (string method) :keyword))
      #'(lambda (,req)
          (call ,(if (eq type 'defclass)
                     `(make-instance ',symbol)
                     `(symbol-function ',symbol))
                ,req)))))

(defun add-query-parameters (base-url params)
  "Add a query parameters string of PARAMS to BASE-URL."
  (unless params
    (return-from add-query-parameters base-url))
  (loop for (name value) on params by #'cddr
        collect (format nil "~A=~A"
                        (urlencode (princ-to-string name))
                        (urlencode (princ-to-string value)))
        into parts
        finally
     (return
       (let ((params-string (format nil "~{~A~^&~}" parts)))
         (format nil "~A~A~A"
                 base-url
                 (if (find #\? base-url) "&" "?")
                 params-string)))))

@doc "
Make an URL for the action with PARAMS.

Example:
  @url GET \"/animals/:type\"
  (defun animals (params))

  (url-for 'animals :type \"cat\")
  ;; => \"/animals/cat\"
"
@export
(defun url-for (symbol &rest params)
  (let* ((package (symbol-package symbol))
         (app (symbol-value (find-symbol "*APP*" package)))
         (route (lookup-route app symbol)))
    (unless route
      (error "Route not found for ~A" symbol))
    (multiple-value-bind (base-url rest-params)
        (rule-url-for (second route) params)
      (add-query-parameters base-url rest-params))))
