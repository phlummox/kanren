; Proving the Deduction Theorem for Hilbert Propositional Calculus
; by induction.
;
; This file is largely based on the paper
; 
; * Deduction for functional programmers
; by James J. Leifer and Bernard Sufrin
; Journal of Functional Programming, volume 6, number 2, 1996.
; http://para.inria.fr/~leifer/research.html
;
; The paper uses Gopher. We use our logic system. You can see
; therefore quite a bit of difference between the two approaches.
;
; The paper stated that the function 'ded' satisfies its specification
; and is therefore a constructive proof of the Deduction Theorem
; (which is an inference rule, as described in the paper).  However,
; the paper merely said that the fact 'ded' satisfies its
; specification *can* be proved by induction -- but the paper gave no
; proof. The following file does give the full inductive proof. The
; proof is automatically checked by our logic system! It is trickier
; than expected because it relies on properties of sets.
;
; The meta-object machinery to build a prover is explained in the
; proof of mirror.
;
; $Id$

(newline)
(display "Inductive proof of the Deduction Theorem for Hilbert Prop Calc")
(newline)

; Well-formed formulas (WFF), see p. 2 of the paper

(define wff
  (lambda (kb)
    (extend-relation (t)
      (relation (w)
	(to-show `(wff (not ,w)))
	(kb `(wff ,w)))
      (relation (w1 w2)
	(to-show `(wff (-> ,w1 ,w2)))
	(all!
	  (kb `(wff ,w1))
	  (kb `(wff ,w2))))
      (relation (w)
	(to-show `(wff ,w))
	(predicate (w) (string? w)))
      )))

; The proof is formed from axiom schemas K, S, Cp, Hyp
; and an application of Modus Ponens, see pp. 2-3
;
; Relation: prf Prf (Hyp ...) Con
; holds if Prf is a valid proof and (Hyp ...) and Con are its
; hypotheses and the conclusion. Hyp and Con must be WFF.
; Our relation 'prf' subsumes the 'Prf' datatype of the paper
; as well as functions 'seq' and 'gp' of the paper.
; Our Prf is a total relation (unlike seq). Whereas the paper separates
; the tasks of checking the validity of the proof (in gp) and extracting
; hypotheses and the conclusion of the proof (in the function seq),
; in our approach, both tasks are combined: for us, an invalid proof cannot
; have conclusions.
; So, our 'prf' acts as a "type predicate" for proofs -- but in a very
; advanced type system.

(define prf
  (lambda (kb)
    (extend-relation (t)
      (relation (x y)
	(to-show `(prf (K ,x ,y) () (-> ,x (-> ,y ,x))))
	(all!
	  (kb `(wff ,x))
	  (kb `(wff ,y))))
      (relation (x y z)
	(to-show `(prf (S ,x ,y ,z) ()
		    (->
		      (-> ,x (-> ,y ,z))
		      (-> (-> ,x ,y) (-> ,x ,z)))))
	(all!
	  (kb `(wff ,x))
	  (kb `(wff ,y))
	  (kb `(wff ,z))))
      (relation (x y)
	(to-show `(prf (Cp ,x ,y) ()
		    (->
		      (-> (not ,x) (not ,y))
		      (-> ,y ,x))))
	(all!
	  (kb `(wff ,x))
	  (kb `(wff ,y))))
      (relation (x)
	(to-show `(prf (Hyp ,x) (,x) ,x))
	(kb `(wff ,x)))
      (relation (p q ps qs ws x y)			; joins two proofs
	(to-show `(prf (MP ,p ,q) ,ws ,y))
	(all!
	  ;(trace-vars 'mpq (p q y))
	  (kb `(prf ,p ,ps ,x))
	  (kb `(prf ,q ,qs (-> ,x ,y)))
	  (kb `(union ,ps ,qs ,ws))))
      )))


; Now, how do we make sure that 'prf' relation is correct? That we haven't
; missed any test? We do it in two parts.

; In the first part we generate inductive hypotheses. We evaluate
; relation 'prf' in a very special knowledge database. The knowledge base
; assumes reports the success of every relation in it. It also
; binds all the free variables in the asked relation to some distinguished
; symbols (we chose the explanation mark to distinguish such names).
; Thus we replace free variables with eigen-variables.
; We thus generate _universal_ induction hypotheses.
; Note that this special 'kb' is only used inductively in prf.
; So, the (pretty-print indc1) in ind-kb-gen below
; will print out all assumptions that 'prf' makes.
; We can manually examine those assumptions to see if they look OK.

; get the free vars of term
(define free-vars
  (lambda (term)
    (let loop ([term term] [fv '()])
      (cond
        [(var? term) (if (memq term fv) fv (cons term fv))]
        [(pair? term) (loop (cdr term) (loop (car term) fv))]
        [else fv]))))

; Replace a logical variable with an eigen-variable
(define universalize
  (lambda (term)
    (let ([fv (free-vars term)])
      (let ([subst
              (map
                (lambda (v)
                  (commitment v
                    (symbol-append '! (var-id v) ': (gensym))))
                fv)])
        (subst-in term subst)))))

(define ind-kb-gen
  (lambda (t)
    (let-lv (ind)
      (all! (== t ind)
	(lambda@ (sk fk subst)
	  (let* ((indc (subst-in ind subst))
		 (indc1 (universalize indc)))
	  (pretty-print indc1)
	  (@ sk fk (unify indc1 t subst))
	  ;(@ sk fk subst)
	  )
      )))))

(printf "~nGenerating inductive hypotheses for prf~n")
(pretty-print (solve 9 (p hs c)
		((prf ind-kb-gen) `(prf ,p ,hs ,c))))

; Of course we want to complement the manual checking of the hypotheses
; with automatic verification of 'prf'
; For example, we want to check that the conclusion of every valid
; proof is a WFF.
; So after we generated all the possible proofs (with eigen-variables
; representing universally-quantified variables) we run our check.
; We use a special knowledge base. This type, the knowledge base
; contains only acceptable hypotheses. The database checks that these
; hypotheses contain only eigen-variables (because true inductive hypotheses
; must be of that kind).

(define (eigenvar? x)
  (predicate (x)
    (and (symbol? x)
      (eqv? #\! (string-ref (symbol->string x) 0)))))

(define ind-kb-test
  (extend-relation (t)
    (relation (x) 
      (to-show `(wff ,x))
      (eigenvar? x))
    (relation (p h c) 
      (to-show `(prf ,p  ,h ,c)))
    (relation (x y z)
      (to-show `(union ,x ,y ,z))
      (all!
	(eigenvar? x)
	(eigenvar? y)
	(eigenvar? z)))
    ))

(printf "~nTesting prf~n")
(pretty-print
  (solve 9 (p hs c)
    (if-some
      ((prf ind-kb-gen) `(prf ,p ,hs ,c))
      ((Y
	 (lambda (kb)
	   (extend-relation (t)
	     ind-kb-test
	     (wff kb))))
	`(wff ,c)))))

; Now, let's test what happens if there were an error.
; Suppose, in the following fragment of 'prf' code above
;       (relation (x y)
; 	(to-show `(prf (K ,x ,y) () (-> ,x (-> ,y ,x))))
; 	(all!
; 	  (kb `(wff ,x))
; 	  (kb `(wff ,y))))
; The user has made an error: suppose he forgot to test that x must
; be a WFF. Now, let's comment out that condition in the above code
; and re-run the file. We shall see a report that a non-eigen
; variable is found. So, we cannot justify the tested property.



; Now we define some properties of sets: unions, difference, intersections

(define sets
  (lambda (kb)
    (extend-relation (t)
      (fact (x) `(union () () ()))
      (fact (x) `(union () ,x ,x))
      (fact (x) `(union ,x () ,x))
      (relation (x xr y z u)
	(to-show `(union (,x . ,xr) ,y ,z))
	(if-only (kb `(member ,x ,y))
	  (kb `(union ,xr ,y ,z))
	  (all! (kb `(union ,xr ,y ,u))
	        (== z (cons x u)))
	  ))
      (fact (x) `(member ,x (,x . ,_)))
      (relation (x l)
	(to-show `(member ,x (,_ . ,l)))
	(kb `(member ,x ,l)))
      (fact () `(subset () ,_))
      (relation (x xr l) 
	(to-show `(subset (,x . ,xr) ,l))
	(all!
	  (kb `(member ,x ,l))
	  (kb `(subset ,xr ,l))))
      (fact () `(without ,_ () ()))
      (relation (x l)
	(to-show `(without ,x (,x . ,l) ,l)))
      (relation (x y l l1)
	(to-show `(without ,x (,y . ,l) (,y . ,l1)))
	(kb `(without ,x ,l ,l1)))
)))

(define Y
  (lambda (f)
    ((lambda (u) (u (lambda (x) (lambda (n) ((f (u x)) n)))))
     (lambda (x) (x x)))))


; needed more tests...
(test-check 'sets
  (solution (z) ((Y sets) `(union (1 2 3) (4 5 1 7) ,z)))
  '((z.0 (2 3 4 5 1 7))))

; Relation 'justifies?'
; Checking if a proof justifies a sequent, see p. 3 of the paper

(define a-wff 'a-wff)			; An eigen-variable!
(define full-kb
  (Y
    (lambda (kb)
      (extend-relation (t)
	(fact () `(wff ,a-wff))
	(wff kb)
	(prf kb)
	(sets kb)))))

; The relation justifies? PRF HS CONCL
; holds if the proof PRF has the same conclusion as CONCL
; with the same or perhaps fewer hypotheses than HS
(define justifies?
  (lambda (kb)
    (relation (p phs hs c)
      (to-show `(justifies? ,p ,hs ,c))
      (all!
	(kb `(prf ,p ,phs ,c))
	(trace-vars 'just (p phs hs c))
	(kb `(subset ,phs ,hs))))))

; Proving that [] |- x -> x
; See p. 3 of the paper

(define (reflex x)
  `(MP (K ,x ,x)
     (MP (K ,x (-> ,x ,x))
       (S ,x (-> ,x ,x) ,x))))

(printf "~nReflex~n")

(pretty-print
  (solve 1 (h c) (full-kb `(prf (K "a" "a") ,h ,c))))

(pretty-print
  (solve 1 (h c) (full-kb `(prf ,(reflex a-wff) ,h ,c))))


; Now, in the following we automatically prove the correctness
; of reflex.
; The paper only says that the correctness proof is simple
; and can be constructed automatically by a system such as Jape
; or Boyer-Moore. Our system can also do that -- easily!

(pretty-print
  (solve 1 (p) ((justifies? full-kb) 
		 `(justifies? ,(reflex a-wff) () (-> a-wff a-wff)))))


(printf "~nDeduction Theorem~n")

; Compare with the function 'ded' on p.5 of the paper
; The relation ded H P Q holds
; if H is a WFF and P and Q are proofs such that
; if P proves C then Q proves H->C without using the
; hypothesis H
; In other words,
;  Q justifies a sequent (hypotheses(P) - H |- H -> conclusion(P))

(define ded
  (lambda (kb)
    (extend-relation (t)
      (relation (h p q hp hq cp rcq)
	(to-show `(ded ,h (MP ,p ,q) 
		    (MP ,hp
		      (MP ,hq
			(S ,h ,cp ,rcq)))))
	(all!
	  (kb `(wff ,h))
	  (kb `(prf ,p ,_ ,cp))
	  (kb `(prf ,q ,_ (-> ,_ ,rcq)))
	  (kb `(ded ,h ,p ,hp))
	  (kb `(ded ,h ,q ,hq))
	  ))
      (relation (h)
	(to-show `(ded ,h (Hyp ,h)
		    ,(reflex h))))
      (relation (h p cp)
	(to-show `(ded ,h ,p (MP ,p (K ,cp ,h))))
	(kb `(prf ,p ,_ ,cp))))))

; Fig. 2
(printf "~nIllustrations of the Deduction Theorem~n")
(define sp '(MP (Hyp "x") (Hyp (-> "x" "y"))))

(define full-kb
  (Y
    (lambda (kb)
      (extend-relation (t)
	(fact () `(wff ,a-wff))
	(sets kb)
	(wff kb)
	(prf kb)
	(ded kb)
	(justifies? kb)))))

(printf "~nIllustrations of the Deduction Theorem: Fig 3~n")
(pretty-print
  (solution (hs c) (full-kb `(prf ,sp ,hs ,c))))

(printf "~nIllustrations of the Deduction Theorem: Fig 4~n")
(pretty-print
  (solution (q hs c) 
    (if-only (full-kb `(ded (-> "x" "y") ,sp ,q))
      (full-kb `(prf ,q ,hs ,c)))))

(printf "~nIllustrations of the Deduction Theorem: Fig 5~n")
(pretty-print
  (solution (r q hs c) 
    (all!! 
      (full-kb `(ded (-> "x" "y") ,sp ,q))
      (full-kb `(ded "x" ,q ,r))
      (full-kb `(prf ,r ,hs ,c)))))


(printf "~nProving correctness of ded~n")

; The following expresses the correctness of ded
(define goal-fwd
  (lambda (kb)
    (relation (h p hs c q hs1)
      (to-show `(goal ,h ,p))
      (all!
	(kb `(prf ,p ,hs ,c))
	(kb `(ded ,h ,p ,q))
	(kb `(without ,h ,hs ,hs1))
	(trace-vars 'goal-fwd (h p hs c q hs1))
	(kb `(justifies? ,q ,hs1 (-> ,h ,c)))
	))))

; what follows if we assume the correctness of ded for some H and P
(define (goal-rev h p hs c q hs1 hsq)
  (extend-relation (t)
    (fact () `(prf ,p ,hs ,c))
    (fact () `(ded ,h ,p ,q))
    (fact () `(without ,h ,hs ,hs1))
    (fact () `(prf ,q ,hsq (-> ,h ,c))) ; from justify?
    (fact () `(subset ,hsq ,hs1))
    ))

(printf "~%First check the base case: K, using goal-fwd ~a~n"
  (solution (foo)
    (let ((kb0
	    (Y (lambda (kb)
		 (extend-relation (t)
		   (fact () '(wff x))
		   (fact () '(wff y))
		   (fact () '(wff h))
		   (sets kb)
		   (wff kb)
		   (prf kb)
		   (ded kb)
		   (justifies? kb))))))
      (let ((kb1 (goal-fwd kb0)))
	(kb1 '(goal h (K x y))))))) ; note, x is an eigenvariable!

(printf "~%First check the base case: S, using goal-fwd ~a~n"
  (solution (foo)
    (let ((kb0
	    (Y (lambda (kb)
		 (extend-relation (t)
		   (fact () '(wff x))
		   (fact () '(wff y))
		   (fact () '(wff z))
		   (fact () '(wff h))
		   (sets kb)
		   (wff kb)
		   (prf kb)
		   (ded kb)
		   (justifies? kb))))))
      (let ((kb1 (goal-fwd kb0)))
	(kb1 '(goal h (S x y z))))))) ; note, x is an eigenvariable!

 (printf "~%First check the base case: Cp, using goal-fwd ~a~n"
  (solution (foo)
    (let ((kb0
	    (Y (lambda (kb)
		 (extend-relation (t)
		   (fact () '(wff x))
		   (fact () '(wff y))
		   (fact () '(wff h))
		   (sets kb)
		   (wff kb)
		   (prf kb)
		   (ded kb)
		   (justifies? kb))))))
      (let ((kb1 (goal-fwd kb0)))
	(kb1 '(goal h (Cp x y)))))))

 (printf "~%First check the base case: Hyp, using goal-fwd ~a~n"
   (solution (foo)
    (let ((kb0
	    (Y (lambda (kb)
		 (extend-relation (t)
		   (fact () '(wff x))
		   (fact () '(wff h))
		   (sets kb)
		   (wff kb)
		   (prf kb)
		   (ded kb)
		   (justifies? kb))))))
      (let ((kb1 (goal-fwd kb0)))
	(kb1 '(goal h (Hyp x)))))))


(printf "~%Some preliminary checks, using goal-rev ~s~%"
; (goal h p) => (MP p q) is a proof
  (solution (hs c)
    (let ((kb
	    (Y (lambda (kb)
		 (extend-relation (t)
		   (fact () '(wff x))
		   (fact () '(wff h))
		   (fact () '(union p-hs q-hs pq-hs))
		   (goal-rev 'p-h 'p 'p-hs 'p-c 'p-q 'p-hs1 'p-hsq)
		   (goal-rev 'q-h 'q 'q-hs '(-> p-c q-c) 'q-q 'q-hs1 'q-hsq)
		   (sets kb)
		   (wff kb)
		   (prf kb)
		   (ded kb)
		   (justifies? kb))))))
      (kb `(prf (MP p q) ,hs ,c)))))

(printf "~%Some preliminary checks, using goal-rev ~s~%"
; (goal h p) => (ded h p _c)
  (solution (hs c)
    (let ((kb
	    (Y (lambda (kb)
		 (extend-relation (t)
		   (fact () '(wff x))
		   (fact () '(wff h))
		   (fact () '(union p-hs q-hs pq-hs))
		   (goal-rev 'h 'p 'p-hs 'p-c 'p-q 'p-hs1 'p-hsq)
		   (goal-rev 'h 'q 'q-hs '(-> p-c q-c) 'q-q 'q-hs1 'q-hsq)
		   (sets kb)
		   (wff kb)
		   (prf kb)
		   (ded kb)
		   (justifies? kb))))))
      (kb `(ded h p ,c)))))


 (printf "~%Check the inductive  case: MP, using goal-fwd ~a~n"
  (solution (foo)
    (let ((kb0
	    (Y (lambda (kb)
		 (extend-relation (t)
		   (fact () '(wff x)) ; inductive hypotheses ...
		   (fact () '(wff h))
		   (fact () '(wff p-c))
		   (fact () '(wff q-c))
		   (fact () '(union p-hs q-hs pq-hs))
		   (fact () '(union p-hsq q-hsq pq-hsq))
		   (fact () '(without h pq-hs pq-hs-h))
		   ;(fact () '(subset pq-hsq pq-hs-h))
		   ; an interesting property of sets
		   ; a1 <= (b1-h)
		   ; a2 <= (b2-h)
		   ; then
		   ; (a1+a2) <= (b1+b2 -h)
		   (relation (a b a1 a2 a1l a2l b1 b2 bl h)
		     (to-show `(subset ,a ,b))
		     (all!
		       (predicate/no-check (a)
			 (and (not (var? a)) (symbol? a)))
		       (predicate/no-check (b)
			 (and (not (var? b)) (symbol? b)))
		       (kb `(union ,a1 ,a2 ,a))
		       (kb `(subset ,a1 ,a1l))
		       (kb `(subset ,a2 ,a2l))
		       (kb `(without ,h ,b1 ,a1l))
		       (kb `(without ,h ,b2 ,a2l))
		       (kb `(union ,b1 ,b2 ,bl))
		       (kb `(without ,h ,bl ,b))))
		   (goal-rev 'h 'p 'p-hs 'p-c 'p-q 'p-hs1 'p-hsq)
		   (goal-rev 'h 'q 'q-hs '(-> p-c q-c) 'q-q 'q-hs1 'q-hsq)
		   (sets kb)
		   (wff kb)
		   (prf kb)
		   (ded kb)
		   (justifies? kb))))))
      (let ((kb1 (goal-fwd kb0)))
	(kb1 '(goal h (MP p q)))))))