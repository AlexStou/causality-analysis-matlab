function yM = rangescale(xM)
% Scale each column to [0,1]. Handle zero-range columns.
n1 = size(xM,1);
mn = min(xM, [], 1);
rg = range(xM, 1);
rg(rg==0) = 1;
yM = (xM - repmat(mn, n1, 1)) ./ repmat(rg, n1, 1);
end


