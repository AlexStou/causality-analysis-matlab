function npV = nneighforgivenr(xM, rV)
% npV = nneighforgivenr(xM, rV)
% Για κάθε σημείο i, μετρά τα σημεία που απέχουν (νόρμα μεγίστου) το πολύ
% rV(i), ΣΥΜΠΕΡΙΛΑΜΒΑΝΟΜΕΝΟΥ του ίδιου του σημείου, δηλαδή n+1, όπως
% απαιτεί ο εκτιμητής KSG (psi(n+1)).
npV = annMaxRvaryquery(xM', xM', rV, 1);   % πλήθος ΧΩΡΙΣ το ίδιο το σημείο
npV = double(npV(:)) + 1;
end
