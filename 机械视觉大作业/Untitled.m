%% 单个印刷数字0~9识别：待测图与模板图完全同源预处理+自制外部模板匹配
clear; clc; close all;

%% ===================== 1. 配置参数 & 读取待识别图片 =====================
[filename,pathname]=uigetfile({'*.jpg;*.png;*.bmp','图像文件(*.jpg,*.png,*.bmp)'});
if isequal(filename,0)
    disp('用户取消选择图片，程序退出');
    return;
end
img=imread(fullfile(pathname,filename));
figure('Name','图像处理全过程');
subplot(3,3,1); imshow(img); title('原图');

%% ===================== 2. 待测图完整预处理：灰度→高斯降噪→二值化→形态学 =====================
% 转灰度图
if size(img,3)==3
    gray_img = rgb2gray(img);
else
    gray_img = img;
end
subplot(3,3,2); imshow(gray_img); title('灰度图');

% 高斯滤波降噪
blur_img = imgaussfilt(gray_img, 1.2);
subplot(3,3,3); imshow(blur_img); title('高斯降噪');

% 自适应二值化
bw_img = adaptthresh(blur_img, 0.4);
bw_img = imbinarize(blur_img, bw_img);
% 统一极性：数字白色，背景黑色
if mean(bw_img(:)) > 0.5
    bw_img = ~bw_img;
end
subplot(3,3,4); imshow(bw_img); title('二值化图像');

% 形态学开运算去噪
se = strel('disk',1);
bw_clean = imopen(bw_img, se);
subplot(3,3,5); imshow(bw_clean); title('形态学去噪');

%% ===================== 3. 待测图轮廓提取+裁剪数字区域 =====================
stats = regionprops(bw_clean, 'BoundingBox', 'Area');
max_area = 0;
bbox = [];
for i = 1:length(stats)
    if stats(i).Area > max_area
        max_area = stats(i).Area;
        bbox = stats(i).BoundingBox;
    end
end
num_crop = imcrop(bw_clean, bbox);
subplot(3,3,6); imshow(num_crop); title('裁剪数字区域');

%% ===================== 4. 统一归一化参数（32×32等比例无拉伸） =====================
target_h = 32;
target_w = 32;
target_size = [target_h, target_w];

% 待测图归一化
[h,w] = size(num_crop);
scale = min(target_w/w, target_h/h);
new_w = round(w * scale);
new_h = round(h * scale);
img_scaled = imresize(num_crop, [new_h, new_w]);
num_resize = false(target_h, target_w);
off_x = floor((target_w - new_w)/2);
off_y = floor((target_h - new_h)/2);
num_resize(off_y+1 : off_y+new_h, off_x+1 : off_x+new_w) = img_scaled;

%% ===================== 5. 【核心修改】模板执行 和原图完全一致全套预处理 =====================
template_set = cell(1,10);
template_root = 'D:\tuku\templates\';  

for n = 0:9
    temp_path = fullfile(template_root, [num2str(n), '.png']);
    temp_raw = imread(temp_path);
    
    % ========== 模板 步骤1：灰度化（和待测图一致） ==========
    if size(temp_raw,3)==3
        t_gray = rgb2gray(temp_raw);
    else
        t_gray = temp_raw;
    end
    
    % ========== 模板 步骤2：高斯降噪（参数完全相同） ==========
    t_blur = imgaussfilt(t_gray, 1.2);
    
    % ========== 模板 步骤3：自适应二值化（阈值完全相同） ==========
    t_thresh = adaptthresh(t_blur, 0.4);
    t_bw = imbinarize(t_blur, t_thresh);
    
    % ========== 模板 步骤4：极性统一（字白背景黑） ==========
    if mean(t_bw(:)) > 0.5
        t_bw = ~t_bw;
    end
    
    % ========== 模板 步骤5：形态学开运算去噪（结构元一致） ==========
    t_clean = imopen(t_bw, strel('disk',1));
    
    % ========== 模板 步骤6：连通域提取、裁剪数字主体（和待测逻辑一致） ==========
    t_stats = regionprops(t_clean, 'BoundingBox', 'Area');
    t_max_area = 0;
    t_bbox = [];
    for k = 1:length(t_stats)
        if t_stats(k).Area > t_max_area
            t_max_area = t_stats(k).Area;
            t_bbox = t_stats(k).BoundingBox;
        end
    end
    t_crop = imcrop(t_clean, t_bbox);
    
    % ========== 模板 步骤7：等比例归一化32×32（缩放规则完全一致） ==========
    [th,tw] = size(t_crop);
    s = min(target_w/tw, target_h/th);
    t_ws = round(tw * s);
    t_hs = round(th * s);
    t_scaled = imresize(t_crop, [t_hs, t_ws]);
    
    t_final = false(target_h, target_w);
    ox = floor((target_w - t_ws)/2);
    oy = floor((target_h - t_hs)/2);
    t_final(oy+1:oy+t_hs, ox+1:ox+t_ws) = t_scaled;
    
    template_set{n+1} = t_final;
end

%% ===================== 6. 归一化互相关模板匹配 =====================
corr_score = zeros(1,10);
for n = 0:9
    temp = template_set{n+1};
    c = normxcorr2(num_resize, temp);
    corr_score(n+1) = max(c(:));
end
[max_val, idx] = max(corr_score);
result_num = idx - 1;

subplot(3,3,7); imshow(num_resize);
title({['归一化数字'],['识别结果：',num2str(result_num)]});

%% 输出最终识别结果
fprintf('识别完成\n');
fprintf('识别数字：%d\n匹配置信度：%.4f\n', result_num, max_val);