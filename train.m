clear; clc; close all;

%% 1. 加载原始数据
theta_rev = (90:-6:0)';   % 反向测量：90° → 0°
I_rev_1 = [0; 8; 32; 75; 130; 194; 274; 356; 443; 527; 605; 673; 732; 774; 800; 808];
I_rev  =I_rev_1;
theta_fwd = (0:6:90)';    % 正向测量：0° → 90°
I_fwd_1 = [808; 799; 775; 732; 674; 603; 528; 445; 357; 276; 196; 130; 75; 33; 8; 0];
I_fwd = I_fwd_1;

% 对称化处理：取正反向平均值，减少噪声，强制对称
% 注意：反向数据 I_rev 对应角度 90°→0°，需翻转后平均
I_avg = (I_rev(end:-1:1) + I_fwd) / 2;  % 得到16个点的对称光强

% 构建训练用角度（0°~90°，步长6°）
theta_avg = (0:6:90)';      % 16×1
% 弧度转换
theta_rad = deg2rad(theta_avg);

% 神经网络输入输出矩阵（1×16行向量）
P = theta_rad';    % 输入：弧度
T = I_avg';        % 输出：平均光强

%% 2. 网络结构调整（采用较小隐含层，避免过拟合）
% 隐含层神经元数：8~10 已足够拟合光滑余弦平方曲线
hiddenNeurons = 8;

% 创建网络（新语法 newff，不产生过时警告）
net = newff(P, T, hiddenNeurons, {'tansig', 'purelin'});

% 若无 Neural Network Toolbox，可改用 feedforwardnet：
% net = feedforwardnet(hiddenNeurons);
% net.layers{1}.transferFcn = 'tansig';
% net.layers{2}.transferFcn = 'purelin';
% net = configure(net, P, T);

%% 3. 训练参数设置（使用贝叶斯正则化算法）
net.trainFcn = 'trainbr';          % 贝叶斯正则化，自动防止过拟合，曲线光滑
net.trainParam.epochs = 500;       % 训练次数，trainbr收敛较慢但效果极佳
net.trainParam.goal   = 1e-10;     % 极小目标误差，实际上会提前停止
net.trainParam.showWindow = true;  % 显示训练窗口观察收敛
net.divideFcn = 'dividetrain';     % 使用全部数据训练，trainbr无需验证集

% 可选：强制性能函数为正则化均方误差（trainbr已内置正则化，此处可省略）
% net.performFcn = 'msereg';
% net.performParam.ratio = 0.9;

%% 4. 多次随机初始化训练，选择最优网络
fprintf('开始多次训练，寻找最优网络...\n');
bestNet = [];
bestMSE = inf;
numTrials = 20;   % 尝试次数

for trial = 1:numTrials
    % 重新初始化网络（权重随机）
    net = init(net);
    % 训练（关闭单独的训练窗口以加速，若想观察可注释掉下一行）
    net.trainParam.showWindow = false;
    [net_trained, tr] = train(net, P, T);
    % 计算在训练点上的均方误差
    Y_pred = net_trained(P);
    mse = mean((Y_pred - T).^2);
    fprintf('试验 %2d: 最终 MSE = %.6e\n', trial, mse);
    if mse < bestMSE
        bestMSE = mse;
        bestNet = net_trained;
    end
end

% 使用最优网络
net = bestNet;
fprintf('最优网络 MSE = %.6e\n', bestMSE);
%保存最佳网络
save('net.mat','net');

%% 5. 仿真与拟合曲线
% 密集点仿真
theta_dense = linspace(0, pi/2, 200);
Y_dense = net(theta_dense);

% 理论曲线（马吕斯定律：I = I0 * cos?θ）
I0_theory = max(T);   % 约 808
I_theory = I0_theory * cos(theta_dense).^2;

%% 6. 误差分析
Y_train = net(P);
mse_train = mean((Y_train - T).^2);
% 相对误差（避免除零）
rel_err = abs(Y_train - T) ./ T * 100;
rel_err(T == 0) = NaN;
max_rel_err = max(rel_err(~isnan(rel_err)));

fprintf('\n===== 拟合结果报告 =====\n');
fprintf('训练集均方误差 MSE = %.6f\n', mse_train);
fprintf('最大相对误差        = %.2f%%\n', max_rel_err);
fprintf('理论最大光强 I0     = %.1f\n', I0_theory);
fprintf('网络预测最大值      = %.1f (在θ=0°处)\n', Y_dense(1));
fprintf('网络预测最小值      = %.4f (在θ=90°处)\n', Y_dense(end));

%% 7. 绘图（弧度/角度双图）
% 弧度图
figure('Position', [100, 100, 800, 500]);
plot(theta_rad, I_avg, 'ko', 'MarkerSize', 7, 'LineWidth', 1.2); hold on;
plot(theta_dense, Y_dense, 'b-', 'LineWidth', 2);
plot(theta_dense, I_theory, 'r--', 'LineWidth', 1.5);
xlabel('夹角 \theta (rad)'); ylabel('相对光强 I');
legend('实验测量数据（平均）', 'BP网络拟合', '理论曲线 (I_0 cos^2\theta)', ...
       'Location', 'best');
title('BP神经网络拟合马吕斯定律');
grid on; hold off;

% 角度图
theta_dense_deg = rad2deg(theta_dense);
figure('Position', [100, 100, 800, 500]);
plot(theta_avg, I_avg, 'ko', 'MarkerSize', 7, 'LineWidth', 1.2); hold on;
plot(theta_dense_deg, Y_dense, 'b-', 'LineWidth', 2);
plot(theta_dense_deg, I_theory, 'r--', 'LineWidth', 1.5);
xlabel('夹角 \theta (°)'); ylabel('光功率 P/uw');
legend('实验测量数据（平均）', 'BP网络拟合', '理论曲线 (P_0 cos^2\theta)', ...
       'Location', 'best');
title('BP神经网络拟合马吕斯定律');
grid on; hold off
