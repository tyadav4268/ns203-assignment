function z = ns203_norminv(p)
% Inverse standard-normal CDF without requiring the Statistics Toolbox.
p = min(max(p, 0.0005), 0.9995);
z = sqrt(2) * erfinv(2 * p - 1);
end
