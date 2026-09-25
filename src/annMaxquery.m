function [inds, dists] = annMaxquery(Xr, Xq, k)
% [inds, dists] = annMaxquery(Xr, Xq, k)
% Nearest neighbors using max-norm (Chebyshev). Fallback MATLAB version.
% Xr: d x n, Xq: d x nq. Returns inds and dists as k x nq.
% Try mex if available
try
	if exist('annMaxquery_mex','file') == 3
		[inds, dists] = annMaxquery_mex(Xr, Xq, int32(k));
		inds = double(inds); dists = double(dists);
		return;
	end
catch
end

% Exact KD-tree acceleration (Statistics and Machine Learning Toolbox).
% Uses the same max-norm (Chebyshev) distance, so neighbors and distances
% are identical to the brute-force fallback below (only tie-breaking among
% exactly-equal distances may differ, which does not affect the estimator).
% knnsearch automatically picks a kd-tree for low dimensions and an
% exhaustive search for high dimensions.
try
	if exist('knnsearch','file') == 2
		nRef = size(Xr, 2);
		kk = min(k, nRef);
		[idx, D] = knnsearch(Xr', Xq', 'K', kk, 'Distance', 'chebychev');
		% knnsearch returns nq x kk (sorted ascending); transpose to kk x nq
		inds = idx';
		dists = D';
		return;
	end
catch
	% Fall through to pure MATLAB brute force on any error
end

% Pure MATLAB fallback
[d, n] = size(Xr);
[d2, nq] = size(Xq);
if d2 ~= d, error('Dimension mismatch.'); end
inds = zeros(k, nq);
dists = inf(k, nq);
% Compute incrementally to save memory if needed
for j = 1:nq
	q = Xq(:, j)';
	% Chebyshev distances to all reference points
	dv = max(abs(bsxfun(@minus, Xr', q)), [], 2);
	[sd, si] = sort(dv, 'ascend');
	kk = min(k, numel(si));
	inds(1:kk, j) = si(1:kk);
	dists(1:kk, j) = sd(1:kk);
end
end


