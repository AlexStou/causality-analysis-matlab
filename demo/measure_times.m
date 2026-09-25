% measure_times.m
% Μέτρηση χρόνων εκτέλεσης των μέτρων για τον Πίνακα 5.3 (Ενότητα 5.7).
% Οι συναρτήσεις του φακέλου src προστίθενται αυτόματα στο path.
% Χρησιμοποιούνται οι προεπιλεγμένες παράμετροι του Πίνακα 4.1.

clear; clc;
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src'));
configs = [5 1000; 10 1000; 20 1000; 10 5000];   % [K N]
measures = {'CC','MI','GCI','CGCI','TE','PTE'};
nrep = 3;                                        % επαναλήψεις, κρατάμε τον διάμεσο

% Προεπιλεγμένες παράμετροι
ccLag = 1; miBins = 10; miLag = 1; p = 1;
m = 2; tau = 1; k = 5; T = 1;

times = NaN(numel(measures), size(configs,1));
for c = 1:size(configs,1)
    K = configs(c,1); N = configs(c,2);
    X = simulate_var1(K, N);
    fprintf('K = %d, N = %d\n', K, N);
    for im = 1:numel(measures)
        tt = NaN(nrep,1);
        for r = 1:nrep
            tic;
            switch measures{im}
                case 'CC',   cc_all(X, ccLag);
                case 'MI',   mi_all(X, miBins, miLag);
                case 'GCI',  GCinAll(X, p, 1);
                case 'CGCI', CGCinall(X, p, 1);
                case 'TE',   TEnneiAll(X, k, T, m, tau);
                case 'PTE',  PTEnneiAll(X, k, T, m, tau);
            end
            tt(r) = toc;
        end
        times(im,c) = median(tt);
        fprintf('  %-5s %10.3f s\n', measures{im}, times(im,c));
    end
end

% Πίνακας αποτελεσμάτων
colNames = arrayfun(@(i) sprintf('K%d_N%d', configs(i,1), configs(i,2)), ...
                    1:size(configs,1), 'UniformOutput', false);
Tbl = array2table(times, 'RowNames', measures, 'VariableNames', colNames);
disp(Tbl);
writetable(Tbl, 'execution_times.csv', 'WriteRowNames', true);

% Στοιχεία υπολογιστή για το κείμενο
fprintf('\nMATLAB: %s\n', version);
fprintf('Υπολογιστής: %s\n', computer);
fprintf('Συμπλήρωσε επεξεργαστή και RAM από τις ρυθμίσεις του συστήματος.\n');

% ---------------- Βοηθητικές συναρτήσεις ----------------
function X = simulate_var1(K, N)
% Γραμμικό αυτοπαλίνδρομο σύστημα πρώτης τάξης με αλυσίδα X1 -> X2 -> ... -> XK
    rng(1);
    A = 0.5*eye(K);
    for i = 2:K, A(i,i-1) = 0.3; end
    burn = 200;
    X = zeros(N+burn, K);
    for t = 2:N+burn
        X(t,:) = X(t-1,:)*A' + randn(1,K);
    end
    X = X(burn+1:end,:);
end

function R = cc_all(X, L)
    K = size(X,2); R = zeros(K);
    for i = 1:K
        for j = 1:K
            if i ~= j
                c = corrcoef(X(1:end-L,i), X(1+L:end,j));
                R(i,j) = c(1,2);
            end
        end
    end
end

function R = mi_all(X, b, L)
    K = size(X,2); R = zeros(K);
    for i = 1:K
        for j = 1:K
            if i ~= j
                x = X(1:end-L,i); y = X(1+L:end,j);
                h = histcounts2(x, y, [b b]);
                pxy = h/sum(h(:)); px = sum(pxy,2); py = sum(pxy,1);
                nz = pxy > 0;
                pp = px*py;
                R(i,j) = sum(pxy(nz).*log2(pxy(nz)./pp(nz)));
            end
        end
    end
end
