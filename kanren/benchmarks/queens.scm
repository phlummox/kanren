;;http://www.sics.se/quintus/queens.pl
;;9-queens program

; SWI-Prolog, (Version 5.0.10), Pentium IV, 2GHz:
; ?- time(dobench(10)).
; % 134,676,991 inferences in 60.43 seconds (2228656 Lips)

; $Id$

(define benchmark_count 100)

(define data '(1 2 3 4 5 6 7 8 9))

; queen(Data, Out) :-
; 	qperm(Data, Out),
; 	safe(Out).

; qperm([], []).
; qperm([X|Y], K) :-
; 	qdelete(U, [X|Y], Z),
; 	K = [U|V],
; 	qperm(Z, V).

; qdelete(A, [A|L], L).
; qdelete(X, [A|Z], [A|R]) :-
; 	qdelete(X, Z, R).
;
; safe([]).
; safe([N|L]) :-
; 	nodiag(N, 1, L),
; 	safe(L).

; nodiag(_, _, []).
; nodiag(B, D, [N|L]) :-
; 	D =\= N - B,
; 	D =\= B - N,
; 	D1 is D + 1,
; 	nodiag(B, D1, L).

(define benchmark
  (letrec
    ((queen
       (relation (head-let data out)
	 (all
	   (qperm data out)
	   (safe out))))

     (qperm
       (extend-relation (a b)
	 (fact () '() '())
	 (relation (x y (once k))
	   (to-show `(,x . ,y) k)
	   (exists (z u v)
	     (all
	       (qdelete u `(,x . ,y) z)
	       (== k `(,u . ,v))
	       (qperm z v))))))

      (qdelete
	(extend-relation (a b c)
	  (fact (a l) a `(,a . ,l) l)
	  (relation ((once x) a z r)
	    (to-show x `(,a . ,z) `(,a . ,r))
	    (qdelete x z r))))

     (safe
       (extend-relation (a)
	 (fact () '())
	 (relation (n l)
	   (to-show `(,n . ,l))
	   (all
	     (nodiag n 1 l)
	     (safe l)))))
     (nodiag
       (extend-relation (a b c)
	 (fact () _ _ '())
	 (relation ((once b) (once d) n l)
	   (to-show b d `(,n . ,l))
	   (project (n b d)
	     (all!!
	       (predicate (not (= d (- n b))))
	       (predicate (not (= d (- b n))))
	       (nodiag b (+ d 1) l))))))
      )
    (lambda (data out)
      (queen data out))))

; (time (solve 1000 ...))
;     17895 collections
;     364186 ms elapsed cpu time, including 5151 ms collecting
;     369844 ms elapsed real time, including 5228 ms collecting
;     19362955352 bytes allocated, including 19360894888 bytes reclaimed


(define benchmark
  (letrec
    ((queen
       (relation (head-let data out)
	 (all
	   (qperm data out)
	   (safe out))))

     (qperm
       (extend-relation (a b)
	 (fact () '() '())
	 (relation (head-let l k)
	   (if-only (project (l) (predicate (pair? l)))
	   (exists (z u v)
	     (all
	       (qdelete u l z)
	       (== k `(,u . ,v))
	       (qperm z v)))))))

      (qdelete
	(extend-relation (a b c)
	  (fact (a l) a `(,a . ,l) l)
	  (relation ((once x) a z r)
	    (to-show x `(,a . ,z) `(,a . ,r))
	    (qdelete x z r))))

     (safe
       (extend-relation (a)
	 (fact () '())
	 (relation (n l)
	   (to-show `(,n . ,l))
	   (all
	     (nodiag n 1 l)
	     (safe l)))))
     (nodiag
       (extend-relation (a b c)
	 (fact () _ _ '())
	 (relation ((once b) (once d) n l)
	   (to-show b d `(,n . ,l))
	   (project (n b d)
	     (all!!
	       (predicate (not (= d (- n b))))
	       (predicate (not (= d (- b n))))
	       (nodiag b (+ d 1) l))))))
      )
    (lambda (data out)
      (queen data out))))

(test-check 'queens-benchmark
  (solve 2 (out) (benchmark data out))
  '(((out.0 (1 3 6 8 2 4 9 7 5))) ((out.0 (1 3 7 2 8 5 9 4 6)))))

'(test-check 'queens-benchmark-time
  (length
    (time (solve 1000 (out) (benchmark data out))))
  352)

; kanren.ss version 3.45
; (time (solve 1000 ...))
;     13193 collections
;     265112 ms elapsed cpu time, including 3682 ms collecting
;     270339 ms elapsed real time, including 3657 ms collecting
; kanren.ss version 3.53
; (time (solve 1000 ...))
;     13476 collections
;     263209 ms elapsed cpu time, including 3625 ms collecting
;     266191 ms elapsed real time, including 3609 ms collecting

