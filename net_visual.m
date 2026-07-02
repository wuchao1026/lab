function Polarization_Multiple
% 自然光通过多个偏振片的光强可视化分析 GUI 
% 修正：使用 polaraxes 创建极坐标区，解决 polarplot 父级错误
% 替换原来的 load('net.mat');
data = load('net.mat');
net = data.net; % 从结构体中取出net变量

% 创建主窗口
hFig = figure('Name', '多偏振片光强分析 (马吕斯定律)', ...
              'NumberTitle', 'off', ...
              'Position', [200, 150, 950, 600], ...
              'Resize', 'on', ...
              'MenuBar', 'none', ...
              'ToolBar', 'figure');

% --- 左侧控制面板 ---
pnlLeft = uipanel('Parent', hFig, 'Title', '参数设置', ...
                  'Units', 'normalized', 'Position', [0.02 0.05 0.28 0.9], ...
                  'FontSize', 10);

% 偏振片数量
uicontrol('Parent', pnlLeft, 'Style', 'text', ...
          'String', '偏振片数量 N:', ...
          'Units', 'normalized', 'Position', [0.1 0.88 0.8 0.08], ...
          'HorizontalAlignment', 'left', 'FontSize', 10);
hEditN = uicontrol('Parent', pnlLeft, 'Style', 'edit', ...
                   'String', '3', ...
                   'Units', 'normalized', 'Position', [0.1 0.82 0.8 0.07], ...
                   'FontSize', 10, 'Callback', @callback_Update);

% 初始光强 I0
uicontrol('Parent', pnlLeft, 'Style', 'text', ...
          'String', '入射自然光强度 I0:', ...
          'Units', 'normalized', 'Position', [0.1 0.73 0.8 0.08], ...
          'HorizontalAlignment', 'left', 'FontSize', 10);
hEditI0 = uicontrol('Parent', pnlLeft, 'Style', 'edit', ...
                    'String', '1', ...
                    'Units', 'normalized', 'Position', [0.1 0.67 0.8 0.07], ...
                    'FontSize', 10, 'Callback', @callback_Update);

% 各偏振片角度
uicontrol('Parent', pnlLeft, 'Style', 'text', ...
          'String', '各偏振片角度 (°)，用逗号分隔:', ...
          'Units', 'normalized', 'Position', [0.1 0.58 0.8 0.08], ...
          'HorizontalAlignment', 'left', 'FontSize', 10);
hEditAngle = uicontrol('Parent', pnlLeft, 'Style', 'edit', ...
                       'String', '0, 45, 90', ...
                       'Units', 'normalized', 'Position', [0.1 0.52 0.8 0.07], ...
                       'FontSize', 10, 'Callback', @callback_Update);

% 更新按钮
uicontrol('Parent', pnlLeft, 'Style', 'pushbutton', ...
          'String', '更新图形', ...
          'Units', 'normalized', 'Position', [0.2 0.4 0.6 0.08], ...
          'FontSize', 11, 'FontWeight', 'bold', ...
          'Callback', @callback_Update);

% 数据表格
hTable = uitable('Parent', pnlLeft, ...
                 'Units', 'normalized', 'Position', [0.05 0.05 0.9 0.3], ...
                 'ColumnName', {'序号', '角度(°)', '输出光强'}, ...
                 'ColumnWidth', {50, 70, 80}, ...
                 'FontSize', 9);

% --- 图形区域 ---
% 光强变化曲线图（笛卡尔坐标）
ax1 = axes('Parent', hFig, 'Units', 'normalized', ...
           'Position', [0.35 0.55 0.62 0.38]);
title(ax1, '各级偏振片输出光强');
xlabel(ax1, '偏振片序号'); ylabel(ax1, '光强');
grid(ax1, 'on'); hold(ax1, 'on');

% 偏振方向图（极坐标区）- 关键修正点
ax2 = polaraxes('Parent', hFig, 'Units', 'normalized', ...
                'Position', [0.35 0.06 0.62 0.40]);
title(ax2, '偏振片透振方向 (长度 ∝ 输出光强)');
% 设置极坐标的零度方向朝上（与物理习惯一致，可选）
ax2.ThetaZeroLocation = 'top';
ax2.ThetaDir = 'clockwise';

% 初始绘图
callback_Update();

% ========== 回调函数 ==========
    function callback_Update(~, ~)
        try
            N = round(str2double(get(hEditN, 'String')));
            I0 = str2double(get(hEditI0, 'String'));
            angles_str = get(hEditAngle, 'String');
            angles = str2num(angles_str); %#ok<ST2NM>
            
            % 参数检查
            if isnan(N) || N < 1 || isnan(I0) || I0 < 0
                errordlg('请输入有效的偏振片数量(≥1)和初始光强(≥0)','输入错误');
                return;
            end
            if isempty(angles) || length(angles) ~= N
                errordlg(sprintf('角度数量必须等于 N=%d，请用逗号分隔 %d 个角度值', N, N), '角度错误');
                return;
            end
            
            % 计算光强
            I = zeros(1, N);
            I(1) = I0 / 2;          % 自然光经第一片
            for k = 2:N
                delta = angles(k) - angles(k-1);
                theta_delta = deg2rad(delta);
                diff_abs = abs(theta_delta);
                mod_rad = mod(diff_abs, pi);
                small_rad = min(mod_rad, pi - mod_rad);
                I(k) = I(k-1) *2* net(small_rad);
            end
            
            % 更新表格
            set(hTable, 'Data', [(1:N)', angles(:), I(:)]);
            
            % ---- 更新光强曲线 ----
            cla(ax1);
            plot(ax1, 1:N, I, 'bo-', 'LineWidth', 2, 'MarkerSize', 8, ...
                 'MarkerFaceColor', 'b');
            xlim(ax1, [0.5, N+0.5]);
            ylim(ax1, [0, max(I0, max(I)*1.2)]);
            grid(ax1, 'on');
            title(ax1, '各级偏振片输出光强');
            xlabel(ax1, '偏振片序号');
            ylabel(ax1, '光强');
            for k = 1:N
                text(ax1, k, I(k), sprintf(' %.3f', I(k)), ...
                     'VerticalAlignment', 'bottom', 'FontSize', 9);
            end
            
            % ---- 更新极坐标方向图 ----
            cla(ax2);
            hold(ax2, 'on');
            maxI = max(I);
            % 设置半径范围，留出标注空间
            ax2.RLim = [0, max(1.2, maxI*1.3)];
            
            for k = 1:N
                theta_rad = deg2rad(angles(k));
                len = I(k);   % 直接用光强值表示长度
                % 绘制方向线段（从原点出发）
                polarplot(ax2, [theta_rad, theta_rad], [0, len], ...
                          'LineWidth', 2.5, 'Color', lines(1));
                % 绘制端点标记
                polarplot(ax2, theta_rad, len, 'o', ...
                          'MarkerSize', 8, 'MarkerFaceColor', 'r');
                % 标注偏振片序号（放在线段外侧略远处）
                text(ax2, theta_rad, len + 0.1*ax2.RLim(2), num2str(k), ...
                     'FontSize', 9, 'HorizontalAlignment', 'center');
            end
            hold(ax2, 'off');
            
        catch ME
            errordlg(['计算或绘图出错: ' ME.message], '错误');
        end
    end
end