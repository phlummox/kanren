; Benchmark nreverse
;
;   David H. D. Warren
;
;   "naive"-reverse a list of 30 integers

; $Id$
;
; SWI-Prolog, (Version 5.0.10), Pentium IV, 2GHz:
; ?- time(dobench(10000)).
; % 5,000,001 inferences in 1.70 seconds (2935780 Lips)



(define benchmark_count 100)

(define data '(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 
	       16 17 18 19 20 21 22 23 24 25 26 27 28 29 30))

; nreverse([X|L0], L) :-
; 	nreverse(L0, L1), concatenate(L1, [X], L).
; nreverse([], []).
; concatenate([X|L1], L2, [X|L3]) :-	
; 	concatenate(L1, L2, L3).
; concatenate([], L, L).

(define benchmark
  (letrec
    ((nreverse
       (extend-relation (a b)
	 (relation (x l0 l)
	   (to-show `(,x . ,l0) l)
	   (exists (l1)
	     (all!
	       (nreverse l0 l1)
	       (concatenate l1 (list x) l))))
	 (fact () '() '())))
      (concatenate
	(extend-relation (a b c)
	  (relation (x l1 l2 l3)
	    (to-show `(,x . ,l1) l2 `(,x . ,l3))
	    (concatenate l1 l2 l3))
	  (fact (l) '() l l)))
      )
    (lambda (data out)
      (nreverse data out))))

; In the following, the problem comes from (list x) in
; (concatenate l1 (list x) l)
; x is a logic variable, so (list x) is an unground term
; So unification of that term with the argument of concatenate
; causes term constructions. And because concatenate is deliberately
; gets invoked many times, the list of the substitution grows and grows.

(define benchmark
  (letrec
    ((nreverse
       (relation (head-let lh l)
	 (exists (x l0)
	   (if-only (== lh `(,x . ,l0))
	     (exists (l1)
	       (all!
		 (nreverse l0 l1)
		 (trace-ant-raw 'cc (concatenate l1 (list x) l))))
	     (all!! (== lh '()) (== l '()))))))
      (concatenate
	(relation (head-let a l2 c)
	  (exists (x l1 l3) ; replacing that with let-lv increases timing
	    (if-all! ((== a `(,x . ,l1)) (== c `(,x . ,l3)))
	      (concatenate l1 l2 l3)
	      (all!! (== a '()) (== l2 c))))))
      )
    (lambda (data out)
      (nreverse data out))))

; If we had applied Proposition 9, the latter would not have been
; necessary. But it is in the interim.

(define benchmark
  (letrec
    ((nreverse
       (relation (head-let lh l)
	 (exists (x l0)
	   (if-only (== lh `(,x . ,l0))
	     (exists (l1)
	       (all!
		 (nreverse l0 l1)
                 (project/no-check (x)
                   (concatenate l1 (list x) l))))
	     (all!! (== lh '()) (== l '()))))))
      (concatenate
	(relation (head-let a l2 c)
	  (exists (x l1 l3) 
	    (if-only (== a `(,x . ,l1))
	      (all!
		(concatenate l1 l2 l3)
                (project/no-check (x l3)
                  (== c `(,x . ,l3))))
	      (all!! (== a '()) (== l2 c))))))
      )
    (lambda (data out)
      (nreverse data out))))

(test-check 'nrev-benchmark
  (solve 1 (out) (benchmark data out))
  '(((out.0 (30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1)))))

; Evaluate the following to see the resulting substitutions
'(query (benchmark data _))

(display "Timing per iterations: ") (display benchmark_count) (newline)
'(time (do ((i 0 (+ 1 i))) ((>= i benchmark_count))
	(query (benchmark data _))))

; dobench(Count) :-
; 	data(Data),
; 	repeat(Count),
; 	benchmark(Data, _Result),
; 	fail.
; dobench(_).
