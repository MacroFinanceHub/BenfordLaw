% [INPUT]
% tab  = A table returned by the "benford_digits" function.
% test = A string representing the test to perform, its value can be one of the following:
%         - AD for the Anderson-Darling test (Choulakian, 1994)
%         - CV for the Cramer-von Mises test (Choulakian, 1994)
%         - DC for the Chebyshev Distance test (Leemis, 2000)
%         - DE for the Euclidean Distance test (Cho & Gaines, 2007)
%         - FR for the Freedman's U2 test (Freedman, 1981)
%         - G2 for the Likelihood Ratio test (Neyman & Pearson, 1933)
%         - J2 for the Joenssen's J2 test (Joenssen, 2014)
%         - JD for the Hotelling's Joint Digits test (Hotelling, 1931)
%         - JS for the Judge-Schechter Mean Deviation test (Judge & Schechter, 2009)
%         - KS for the Kolmogorov-Smirnov test (Kolomonorgov, 1933)
%         - KU for the Kuiper test (Kuiper, 1960)
%         - T2 for the Freeman-Tukey T2 test (Freeman & Tukey, 1950)
%         - U2 for the Watson's U2 test (Choulakian, 1994)
%         - X2 for the Pearson's X2 test (Pearson, 1900)
% a    = A float [0.01,0.10] representing the statistical significance threshold for the test (optional, default=0.05).
% sims = An integer representing the number of Monte Carlo simulations to perform (optional, default=10000).
%        It should only be specified for the following tests that don't implement an asymptotic p-value computation: DC, DE, FR, J2.
%
% [OUTPUT]
% h0   = A boolean indicating whether the null hypothesis is accepted (true) or rejected (false).
% stat = A float representing the statistic value.
% pval = A float representing the p-value associated to the statistic.

function [h0,stat,pval] = benford_gof(varargin)

    persistent p;

    if (isempty(p))
        p = inputParser();
        p.addRequired('tab',@(x)validateattributes(x,{'table'},{}));
        p.addRequired('test',@(x)any(validatestring(x,{'AD','CV','DC','DE','FR','G2','J2','JD','JS','KS','KU','T2','U2','X2'})));
        p.addOptional('a',0.05,@(x)validateattributes(x,{'double','single'},{'scalar','real','finite','>=',0.01,'<=',0.10}));
        p.addOptional('sims',10000,@(x)validateattributes(x,{'numeric'},{'scalar','real','finite','integer','>=',1000}));
    end

    p.parse(varargin{:});

    res = p.Results;
    tab = res.tab;
    test = res.test;
    a = res.a;
    sims = res.sims;

    if ((nargin == 5) && ~any(strcmp(test,{'DC' 'DE' 'FR' 'J2'})))
        error('The ''sims'' parameter should only be specified for tests based on Monte Carlo simulations (DC, DE, FR, J2).');
    end

    switch (nargout)
        case 1
            h0 = benford_test_internal(tab,test,a,sims);
    
        case 3
            [h0,stat,pval] = benford_gof_internal(tab,test,a,sims);

        otherwise
            error('Only 1 or 3 output arguments can be specified.');
    end

end

function [h0,stat,pval] = benford_gof_internal(tab,test,a,sims)

    switch (test)
        case 'AD'
            [stat_int,pval_int] = calculate_ad(tab);
        
        case 'CV'
            [stat_int,pval_int] = calculate_cv(tab);
        
        case 'DC'
            [stat_int,pval_int] = calculate_dc(tab,sims);

        case 'DE'
            [stat_int,pval_int] = calculate_de(tab,sims);
        
        case 'FR'
            [stat_int,pval_int] = calculate_fr(tab,sims);

        case 'G2'
            [stat_int,pval_int] = calculate_g2(tab);

        case 'J2'
            [stat_int,pval_int] = calculate_j2(tab,sims);

        case 'JD'
            [stat_int,pval_int] = calculate_jd(tab);
            
        case 'JS'
            [stat_int,pval_int] = calculate_js(tab);
            
        case 'KS'
            [stat_int,pval_int] = calculate_ks(tab);

        case 'KU'
            [stat_int,pval_int] = calculate_ku(tab);

        case 'T2'
            [stat_int,pval_int] = calculate_t2(tab);

        case 'U2'
            [stat_int,pval_int] = calculate_u2(tab);

        case 'X2'
            [stat_int,pval_int] = calculate_x2(tab);
    end

    h0 = pval_int >= a;

    if (nargout > 1)
        stat = stat_int;
        pval = pval_int;
    end

end

function [stat,pval] = calculate_ad(tab)

    k = height(tab);
    n = sum(tab.EmpC);

    emp_f = tab.EmpF;
    the_f = tab.TheF;
    the_p = tab.TheP;

    t = (the_p + [the_p(2:end); the_p(1)]) ./ 2;
    z = emp_f - the_f;
    zv = the_f .* (1 - the_f);

    stat = ((z .^ 2) .* t) ./ zv;
    stat = n * sum(stat(1:end-1));
    
    a = tril(ones(k));
    s0 = diag(the_p) - (the_p * the_p.');
    sy = a * s0 * a.';

    e = diag(t);
    q = diag([(1 ./ zv(1:end-1)); 0]);
    m = e * q;
    lam = eig(m * sy);
    
    fun_rho = @(u,lam) exp(sum(bsxfun(@(x,y) log(1 + ((x ^ 2) .* (y .^ 2))),u,lam),1) .* 0.25);
    fun_the = @(u,stat,lam) sum(bsxfun(@(x,y) 0.5 .* atan(x .* y),u,lam),1) - ((0.5 * stat) .* u);
    fun_int = @(u) sin(fun_the(u,stat,lam)) ./ (u .* fun_rho(u,lam));
    
    pval = 0.5 + (integral(fun_int,0,Inf) / pi());
    pval = max([0 min([pval 1])]);
    
    if (pval <= 0.001)
        a_x = stat / max(lam);
        a_v = sum(lam ~= 0);
        a = chi2pdf(a_x,a_v);

        b_fun = @(x) (-x * stat) - (0.5 .* sum(log(1 - (2 .* x .* lam))));
        b_x0 = 1 / (4 * max(lam));
        [~,b] = fminsearch(b_fun,b_x0,optimset('Display','off'));
        b = exp(b);

        pval = min([a b]);
        pval = max([0 min([pval 1])]);
    end

end

function [stat,pval] = calculate_cv(tab)

    k = height(tab);
    n = sum(tab.EmpC);

    emp_f = tab.EmpF;
    the_f = tab.TheF;
    the_p = tab.TheP;

    t = (the_p + [the_p(2:end); the_p(1)]) ./ 2;
    z = emp_f - the_f;
    
    stat = n * sum((z .^ 2) .* t);

    a = tril(ones(k));
    s0 = diag(the_p) - (the_p * the_p.');
    sy = a * s0 * a.';
    
    m = diag(t);
    lam = eig(m * sy);
    
    fun_rho = @(u,lam) exp(sum(bsxfun(@(x,y) log(1 + ((x ^ 2) .* (y .^ 2))),u,lam),1) .* 0.25);
    fun_the = @(u,stat,lam) sum(bsxfun(@(x,y) 0.5 .* atan(x .* y),u,lam),1) - ((0.5 * stat) .* u);
    fun_int = @(u) sin(fun_the(u,stat,lam)) ./ (u .* fun_rho(u,lam));
    
    pval = 0.5 + (integral(fun_int,0,Inf) / pi());
    pval = max([0 min([pval 1])]);
    
    if (pval <= 0.001)
        a_x = stat / max(lam);
        a_v = sum(lam ~= 0);
        a = chi2pdf(a_x,a_v);
        
        b_fun = @(x) (-x * stat) - (0.5 .* sum(log(1 - (2 .* x .* lam))));
        b_x0 = 1 / (4 * max(lam));
        [~,b] = fminsearch(b_fun,b_x0,optimset('Display','off'));
        b = exp(b);

        pval = min([a b]);
        pval = max([0 min([pval 1])]);
    end

end

function [stat,pval] = calculate_dc(tab,sims)

    k = height(tab);
    n = sum(tab.EmpC);
    adj = sqrt(n);

    emp_p = tab.EmpP;
    the_f = tab.TheF;
    the_p = tab.TheP;

    h0 = zeros(1,sims);
    
    for i = 1:sims
        emp_p_sim = simulate_frequency(the_f,k,n);
        h0(i) = adj * max(abs(emp_p_sim - the_p));
    end

    stat = adj * max(abs(emp_p - the_p));

    pval = sum(h0 >= (stat - 1e-8)) / sims;
    pval = max([0 min([pval 1])]);

end

function [stat,pval] = calculate_de(tab,sims)

    k = height(tab);
    n = sum(tab.EmpC);
    adj = sqrt(n);

    emp_p = tab.EmpP;
    the_f = tab.TheF;
    the_p = tab.TheP;

    h0 = zeros(1,sims);

    for i = 1:sims
        emp_p_sim = simulate_frequency(the_f,k,n);
        h0(i) = adj * sqrt(sum((emp_p_sim - the_p) .^ 2));
    end

    stat = adj * sqrt(sum((emp_p - the_p) .^ 2));

    pval = sum(h0 >= (stat - 1e-8)) / sims;
    pval = max([0 min([pval 1])]);

end

function [stat,pval] = calculate_fr(tab,sims)

    k = height(tab);
    n = sum(tab.EmpC);
    adj = n / (k ^ 2);

    emp_p = tab.EmpP;
    the_f = tab.TheF;
    the_p = tab.TheP;
    
    h0 = zeros(1,sims);
    
    for i = 1:sims
        emp_p_sim = simulate_frequency(the_f,k,n);
        diff_f = cumsum(emp_p_sim - the_p);

        h0(i) = adj * ((sum(diff_f .^ 2) * k) - (sum(diff_f) ^ 2));
    end

    diff_f = cumsum(emp_p - the_p);
    stat = adj * ((sum(diff_f .^ 2) * k) - (sum(diff_f) ^ 2));

    pval = sum(h0 >= (stat - 1e-8)) / sims;
    pval = max([0 min([pval 1])]);

end

function [stat,pval] = calculate_g2(tab)

    k = height(tab);
    n = sum(tab.EmpC);

    emp_p = tab.EmpP;
    the_p = tab.TheP;

    stat = 2 * n * sum((emp_p .* log(emp_p + eps())) - (emp_p .* log(the_p + eps())));
    
    pval = 1 - chi2cdf(stat,(k - 1));
    pval = max([0 min([pval 1])]);

end

function [stat,pval] = calculate_j2(tab,sims)

    k = height(tab);
    n = sum(tab.EmpC);

    emp_p = tab.EmpP;
    the_f = tab.TheF;
    the_p = tab.TheP;
    
    h0 = zeros(1,sims);
    
    for i = 1:sims
        emp_p_sim = simulate_frequency(the_f,k,n);
        r = corr(emp_p_sim,the_p);

        h0(i) = sign(r) * (r ^ 2);
    end

    r = corr(emp_p,the_p);
    stat = sign(r) * (r ^ 2);

    pval = sum(h0 >= (stat - 1e-8)) / sims;
    pval = max([0 min([pval 1])]);

end

function [stat,pval] = calculate_jd(tab)

    k = height(tab);
    n = sum(tab.EmpC);

    emp_p = tab.EmpP;
    the_p = tab.TheP;

    cm = -1 .* (the_p * the_p.');
    cm(logical(eye(k))) = the_p .* (1 - the_p);

    [v,d] = eig(cm,'balance','vector');
    [d,idx_sort] = sort(real(d),1,'descend');
    v = v(:,idx_sort);
    
	idx_tol = d >= mean(d);
    d_tol = d(idx_tol);
    v_tol = v(:,idx_tol);

    emp_comp = emp_p.' * v_tol;
    the_comp = the_p.' * v_tol;
    diff = emp_comp - the_comp;

    if (numel(d_tol) == 1)
        stat = (n / d_tol) * (diff ^ 2);
    else
        stat = n * ((diff / diag(d_tol)) * diff.');
    end

    pval = 1 - chi2cdf(stat,numel(d_tol));
    pval = max([0 min([pval 1])]);
 
end

function [stat,pval] = calculate_js(tab)

    dgts = tab.Digits;
    dgts_max = dgts(end);
    n = sum(tab.EmpC);
    
    emp_p = tab.EmpP;
    emp_mu = sum(dgts .* emp_p);

    the_p = tab.TheP;
    the_mu = sum(dgts .* the_p);
    the_var =  sum(((dgts - the_mu) .^ 2) .* the_p);
    
    norm_mean = 0;
    norm_var = sqrt(the_var / n) / (dgts_max - the_mu);
    norm = truncate(makedist('Normal','mu',norm_mean,'sigma',norm_var),0,Inf);
    
    stat = abs(emp_mu - the_mu) / (dgts_max - the_mu);

    pval = (1 - cdf(norm,stat)) * 2;
    pval = max([0 min([pval 1])]);

end

function [stat,pval] = calculate_ks(tab)

    n = sum(tab.EmpC);

    emp_f = tab.EmpF;
    the_f = tab.TheF;

    stat = (sqrt(n) + 0.120 + (0.110 / sqrt(n))) * max(abs(emp_f - the_f));

    pval = 2 * exp(-2 * (stat ^ 2));
    pval = max([0 min([pval 1])]);

end

function [stat,pval] = calculate_ku(tab)

    n = sum(tab.EmpC);

    emp_f = tab.EmpF;
    the_f = tab.TheF;

    stat = (sqrt(n) + 0.155 + (0.240 / sqrt(n))) * (max(emp_f - the_f) + max(the_f - emp_f));

    pval = ((8 * (stat ^ 2)) - 2) * exp(-2 * (stat ^ 2));
    pval = max([0 min([pval 1])]);

end

function [stat,pval] = calculate_t2(tab)

    k = height(tab);
    n = sum(tab.EmpC);

    emp_p = tab.EmpP;
    the_p = tab.TheP;

    stat = n * sum((sqrt(emp_p) + sqrt(emp_p + 1) - sqrt((4 .* the_p) + 1)) .^ 2);

    pval = 1 - chi2cdf(stat,(k - 1));
    pval = max([0 min([pval 1])]);

end

function [stat,pval] = calculate_u2(tab)

    k = height(tab);
    n = sum(tab.EmpC);

    emp_f = tab.EmpF;
    the_f = tab.TheF;
    the_p = tab.TheP;

    t = (the_p + [the_p(2:end); the_p(1)]) ./ 2;
    z = emp_f - the_f;
    zm = sum(z .* t);
    
    stat = n * sum(((z - zm) .^ 2) .* t);
    
    a = tril(ones(k));
    s0 = diag(the_p) - (the_p * the_p.');
    sy = a * s0 * a.';

    e = diag(t);
    m_iden = eye(k);
    m_ones = ones(k);
    m = (m_iden - (e * m_ones)) * e * (m_iden - (m_ones * e));
    lam = eig(m * sy);
    
    fun_rho = @(u,lam) exp(sum(bsxfun(@(x,y) log(1 + ((x ^ 2) .* (y .^ 2))),u,lam),1) .* 0.25);
    fun_the = @(u,stat,lam) sum(bsxfun(@(x,y) 0.5 .* atan(x .* y),u,lam),1) - ((0.5 * stat) .* u);
    fun_int = @(u) sin(fun_the(u,stat,lam)) ./ (u .* fun_rho(u,lam));
    
    pval = 0.5 + (integral(fun_int,0,Inf) / pi());
    pval = max([0 min([pval 1])]);
    
    if (pval <= 0.001)
        a_x = stat / max(lam);
        a_v = sum(lam ~= 0);
        a = chi2pdf(a_x,a_v);
        
        b_fun = @(x) (-x * stat) - (0.5 .* sum(log(1 - (2 .* x .* lam))));
        b_x0 = 1 / (4 * max(lam));
        [~,b] = fminsearch(b_fun,b_x0,optimset('Display','off'));
        b = exp(b);

        pval = min([a b]);
        pval = max([0 min([pval 1])]);
    end

end

function [stat,pval] = calculate_x2(tab)

    k = height(tab);
    n = sum(tab.EmpC);

    emp_p = tab.EmpP;
    the_p = tab.TheP;

    stat = n * sum(((emp_p - the_p) .^ 2) ./ the_p);

    pval = 1 - chi2cdf(stat,(k - 1));
    pval = max([0 min([pval 1])]);

end

function sim = simulate_frequency(the_f,k,n)

    r = rand(1,n);
    c = bsxfun(@gt,r,the_f);
    x = sum(c) + 1;

    sim = (histcounts(x,[1:k Inf]) ./ n)';

end