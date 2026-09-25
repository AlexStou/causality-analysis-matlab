% run_demo.m
% Επίδειξη του λογισμικού: υπολογισμός των έξι μέτρων (CC, MI, GCI, CGCI,
% TE, PTE) σε ένα σύνολο δεδομένων, χωρίς τη γραφική διεπαφή.
%
% Χρήση:   run_demo                  % συνθετικό μηχανολογικό σύστημα (προεπιλογή)
%          run_demo('oikonomika')        % συνθετικό οικονομικό σύστημα
%          run_demo('pragmatika_mixanologika')   % πραγματικά δεδομένα κατοικίας
%          run_demo('pragmatika_oikonomika')     % πραγματικοί οικονομικοί δείκτες
%
% Για τα συνθετικά συστήματα, όπου η δομή αιτιότητας είναι γνωστή, το demo
% συγκρίνει τις σημαντικές σχέσεις του CGCI με τις πραγματικές.
% Για τη γραφική διεπαφή:  cd src; app1
%
% Παράμετροι: οι προεπιλογές του λογισμικού (Πίνακας 4.1 της εργασίας),
% με υστέρηση ℓ = 1 για τη CC.

function run_demo(dataset)
if nargin < 1, dataset = 'mixanikou'; end
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'src'));

% ---------- Φόρτωση δεδομένων ----------
f = fullfile(root, 'data', 'synthetic', [dataset '.txt']);
if ~isfile(f), f = fullfile(root, 'data', 'real', [dataset '.txt']); end
if ~isfile(f), error('Δεν βρέθηκε το αρχείο δεδομένων "%s".', dataset); end
T = readtable(f, 'FileType', 'text', 'Delimiter', '\t');
if strcmpi(T.Properties.VariableNames{1}, 'Time'), T(:,1) = []; end
X = T{:,:};
names = T.Properties.VariableNames;
[N, K] = size(X);
fprintf('\nΣύνολο δεδομένων: %s  (N = %d, K = %d)\n', dataset, N, K);
fprintf('Μεταβλητές: %s\n\n', strjoin(names, ', '));

% ---------- Παράμετροι ----------
ccLag = 1; alpha = 0.05;          % CC
miBins = 10; miLag = 1;           % MI
p = 1;                            % GCI, CGCI
m = 2; tau = 1; k = 5; Th = 1;    % TE, PTE

% ---------- Υπολογισμός ----------
tic; [CC, pCC] = ccAll(X, ccLag);           t(1) = toc;
tic; MI = miAll(X, miBins, miLag);          t(2) = toc;
tic; [GCI, pGCI] = GCinAll(X, p, 1);        t(3) = toc;
tic; [CGCI, pCGCI] = CGCinall(X, p, 1);     t(4) = toc;
tic; TE = TEnneiAll(X, k, Th, m, tau);      t(5) = toc;
tic; PTE = PTEnneiAll(X, k, Th, m, tau);    t(6) = toc;
M = {CC, MI, GCI, CGCI, TE, PTE};
lab = {'CC (lag 1)', 'MI (lag 1)', 'GCI', 'CGCI', 'TE', 'PTE'};
for i = 1:6, M{i}(1:K+1:end) = NaN; end      % η διαγώνιος δεν ορίζεται

for i = 1:6
    fprintf('%s  (%.2f s)   [γραμμή = αιτία, στήλη = αποτέλεσμα]\n', lab{i}, t(i));
    disp(array2table(round(M{i}, 3), 'VariableNames', names, 'RowNames', names));
end

% ---------- Σημαντικές σχέσεις (έλεγχος F) ----------
fprintf('Σημαντικές σχέσεις του CGCI (p < %.2f):\n', alpha);
printEdges(pCGCI < alpha, names);
fprintf('Σημαντικές σχέσεις του CGCI μετά τη διόρθωση FDR (Benjamini-Hochberg):\n');
printEdges(fdr(pCGCI, alpha), names);

% ---------- Σύγκριση με τη γνωστή δομή (συνθετικά δεδομένα) ----------
A = trueStructure(dataset, names);
if ~isempty(A)
    S = pCGCI < alpha; S(1:K+1:end) = false;
    fprintf('Σύγκριση CGCI με τη γνωστή δομή: %d/%d πραγματικές σχέσεις εντοπίστηκαν, %d ψευδώς θετικές.\n\n', ...
        nnz(S & A), nnz(A), nnz(S & ~A));
end

% ---------- Θερμικοί χάρτες ----------
figure('Name', ['Demo: ' dataset], 'Color', 'w', 'Position', [100 100 1200 650]);
tl = tiledlayout(2, 3, 'TileSpacing', 'compact');
title(tl, sprintf('%s (N = %d, K = %d)', dataset, N, K), 'Interpreter', 'none');
for i = 1:6
    ax = nexttile;
    h = imagesc(ax, M{i}); set(h, 'AlphaData', ~isnan(M{i}));
    set(ax, 'Color', [0.85 0.85 0.85], 'XTick', 1:K, 'YTick', 1:K, ...
        'XTickLabel', names, 'YTickLabel', names, 'TickLabelInterpreter', 'none');
    xtickangle(ax, 45); axis(ax, 'square'); colorbar(ax); title(ax, lab{i});
end
fprintf('Για τη γραφική διεπαφή:  cd(''%s''); app1\n', fullfile(root, 'src'));
end

% ======================= Βοηθητικές συναρτήσεις =======================
function [R, P] = ccAll(X, L)
% R(i,j) = corr(x_i(t), x_j(t+L)), με δίπλευρο έλεγχο t
K = size(X, 2); R = zeros(K); P = ones(K); ne = size(X, 1) - L;
for i = 1:K
    for j = 1:K
        if i == j, continue; end
        c = corrcoef(X(1:end-L, i), X(1+L:end, j)); r = c(1, 2);
        tt = abs(r) * sqrt((ne - 2) / (1 - r^2));
        R(i, j) = r; P(i, j) = 2 * (1 - tcdf(tt, ne - 2));
    end
end
end

function I = miAll(X, b, L)
% I(i,j) = I(x_i(t); x_j(t+L)) σε bits, με εκτιμητή ιστογράμματος b x b
K = size(X, 2); I = zeros(K);
for i = 1:K
    for j = 1:K
        if i == j, continue; end
        h = histcounts2(X(1:end-L, i), X(1+L:end, j), [b b]);
        pxy = h / sum(h(:)); pp = sum(pxy, 2) * sum(pxy, 1); nz = pxy > 0;
        I(i, j) = sum(pxy(nz) .* log2(pxy(nz) ./ pp(nz)));
    end
end
end

function S = fdr(P, q)
% Διόρθωση Benjamini-Hochberg στα μη-διαγώνια στοιχεία
K = size(P, 1); off = ~eye(K); pv = P(off); [ps, idx] = sort(pv);
M = numel(ps); r = find(ps <= (1:M)' * q / M, 1, 'last');
sig = false(M, 1); if ~isempty(r), sig(idx(1:r)) = true; end
S = false(K); S(off) = sig;
end

function printEdges(S, names)
S(1:size(S,1)+1:end) = false; [i, j] = find(S);
if isempty(i), fprintf('  (καμία)\n\n'); return; end
for q = 1:numel(i), fprintf('  %s -> %s\n', names{i(q)}, names{j(q)}); end
fprintf('\n');
end

function A = trueStructure(dataset, names)
% Άμεσες σχέσεις των συνθετικών συστημάτων (Πίνακες 5.1 και 5.2 της εργασίας)
switch dataset
    case 'mixanikou'
        E = {'Pump','Flow'; 'Flow','Press'; 'Press','Temp1'; 'Temp1','Temp2'; 'Pump','Vib'};
    case 'oikonomika'
        E = {'Oil','Rate'; 'Rate','Invest'; 'Invest','GDP'; 'GDP','Stock'; 'Oil','Stock'};
    otherwise
        A = []; return;
end
A = false(numel(names));
for q = 1:size(E, 1)
    A(strcmp(names, E{q,1}), strcmp(names, E{q,2})) = true;
end
end
