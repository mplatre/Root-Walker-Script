%Clears and deletes all variable and plots from MATLAB before running
clear;
close all;

thresh_val  = 0.52;
rm_small = 8000;
rm_large = 150000;

%Prompt user to select folders for experiment and immediately error checks
parent_folder = uigetdir('', 'Select parent folder of genotype and condtion folder');
if parent_folder == 1
    return
end

output_path = uigetdir('', 'Select folder for data output');
if output_path == 0
    return
end

output_name = input('Type in a name for the output movie and images:\n','s');
output_name = strrep(output_name, " ", "_");

tic;

parent_folder_split = strsplit(parent_folder, "\");
date_exp_ID = parent_folder_split{end};

%Child 2 is the name of the GenotypeX_conditionX folders
child_2 = dir(parent_folder);
dir_child_2 = [child_2.isdir] & ~strcmp({child_2.name},'.') & ~strcmp({child_2.name},'..');
child_2_sub = child_2(dir_child_2);

%Save part of the file path to shorten for further use
pre_x = strcat(parent_folder, '\', date_exp_ID, '\');

%Next we will split up and process the folder names into data for export
parent_split_1 = strsplit(parent_folder, '\');
parent_split_2 = strsplit(parent_split_1{end}, '_');
date = str2num(parent_split_2{1});
experiment_num = parent_split_2{2};
gene_cond_cell = struct2cell(child_2_sub);

%Initializing variables for storing root data and images
root_vals = {};
t_step = {};
t_step_proc = {};
xfold_t_step = {};
xfold_t_step_proc = {};

for n = 1:length(child_2_sub) %loops through each genotype_condition
    
    child_3 = dir(strcat(parent_folder, '\', child_2_sub(n).name));
    dir_child_3 = [child_3.isdir] & ~strcmp({child_3.name},'.') & ~strcmp({child_3.name},'..');
    child_3_sub = child_3(dir_child_3);
    
    child_4 = dir(strcat(parent_folder, '\', child_2_sub(n).name, '\', child_3_sub(1).name));
    dir_child_4 = [child_4.isdir] & ~strcmp({child_4.name},'.') & ~strcmp({child_4.name},'..');
    child_4_sub = child_4(dir_child_4);
    
    Tfolders = dir(strcat(parent_folder, '\', child_2_sub(n).name, '\', child_3_sub(1).name, '\', child_4_sub.name));
    dirFolders = [Tfolders.isdir] & ~strcmp({Tfolders.name},'.') & ~strcmp({Tfolders.name},'..');
    subFolders = Tfolders(dirFolders);
    
    %Save part of the file path to shorten for further use
    pre_x = strcat(parent_folder, '\', child_2_sub(n).name, '\', child_3_sub.name, '\', child_4_sub.name, '\');
    
    
    for i = 1:length(subFolders) %loops through each T
        
        collage = [];
        collage_loc = strcat(pre_x, subFolders(i).name, '\');
        files = dir(strcat(collage_loc,'\**\*.tif'));
        fprintf('T: %d\n', i);
        
        %Make the collage of all of the images for each timestep
        for j = 1:length(files)
            image_dir = strcat(collage_loc, '\',  files(j).name);
            imdata = imread(image_dir);
            %Static 30% overlap based on a width of 1920
            %0.3*1920 = 576
            collage = [collage imdata(:,577:1920)];
        end
               
        %Save the collage for later video making
        t_step{i} = collage;
        
        %Perform analysis for each time before moving to next timestep
        
        %Thresholding the image
        BW = imbinarize(collage,'adaptive','ForegroundPolarity','dark','Sensitivity', thresh_val);
        BW_remove = imcomplement(bwareafilt(imcomplement(BW),[rm_small rm_large]));
        
        %Image smoothing to correct for jagged root edges
        N = 21;
        kernel = ones(N, N, N) / N^3;
        blurryImage = convn(double(BW_remove), kernel, 'same');
        sBW = imcomplement(blurryImage < 0.01);
        
        row_pixel = cleanedges(sBW); %calls a function that cleans the edges
        
        [h,w] = size(row_pixel);
        
        %We save the black and white photo for later video making
        t_step_proc{i} = row_pixel;
        
        %Calls a function to convert from binary to a cell array containing
        %connected pixel midpoints
        image_root_pos = con_midpoint(row_pixel, 2);
        
        anchor = image_root_pos{1};
        
        root_vals{i} = anchor;
        
        if i > 1
            %If a root is added or dropped, ignore and use previous starting
            %anchor and update in dataset
            if length(anchor) ~= length(root_vals(i-1))
                anchor = root_vals{i-1};
                root_vals(i) = root_vals(i-1);
            end
        end
        
        for k = 1:length(anchor) %loops for each root
            
            prev_root_center = anchor(k);
            cur_row = 2;
            
            for l = 2:h %loops through all rows of image
                cur_root_center = image_root_pos{l};
                
                %If it reaches the end of all roots, stop
                if isempty(cur_root_center)
                    break
                end
                
                %Loops through all detected segments in row
                for m = 1:length(cur_root_center)
                    delta_center = abs(cur_root_center(m)-prev_root_center);
                    
                    %Detects the end of the specific root in case there
                    %is another object below it
                    if cur_row < l
                        break
                    end
                    
                    %If there is a segment with a center within 30 pixels
                    %of the previous center of the same root
                    if delta_center < 30
                        
                        if delta_center > 5 %special case for large deltaX
                            factor = 2;
                            
                            if cur_root_center(m) < prev_root_center
                                root_data{l-1,k,i} = prev_root_center - delta_center/factor;
                                prev_root_center = cur_root_center(m) - delta_center/factor;
                                cur_row = cur_row + 1;
                            elseif cur_root_center(m) > prev_root_center
                                root_data{l-1,k,i} = prev_root_center + delta_center/factor;
                                prev_root_center = cur_root_center(m) + delta_center/factor;
                                cur_row = cur_row + 1;
                            end
                            break
                        end
                        
                        
                        %Normal case math and stepping through rows for center line
                        root_data{l-1,k, i} = prev_root_center;
                        prev_root_center = cur_root_center(m);
                        cur_row = cur_row + 1;
                        
                        break
                    end
                end
            end
        end
        
        root_data{h,1,1} = []; %ensures consistent height for dataset
        
    end
    
    root_data{h,k,i} = []; %ensures consistent depth for dataset
    
    xfold_t_step{n} = t_step;
    xfold_t_step_proc{n} = t_step_proc;
    xfold_all_root_data{n} = root_data;
    
    temp_root_data = root_data;
    
    clear root_data;
end

xfold_all_root_rate = {};
xfold_all_root_length = {};
xfold_all_root_dist = {};
xfold_all_root_overwrite = {};

for n = 1:length(child_2_sub)
    
    root_overwrite = xfold_all_root_data{n};
    [h,root_num,time] = size(xfold_all_root_data{n});
    
    for i = 1:root_num
        for j = 2:time
            prev = root_overwrite(:,i,j-1);
            next = root_overwrite(:,i,j);
            index = find(~cellfun('isempty', prev),1,'last');
            
            updated = vertcat(prev(1:index), next(index+1:end));
            
            if isempty(updated) %When the root is empty, repost it as empty
                updated = prev;
            end
            root_overwrite(:,i,j) = updated;
        end
    end
    
    %Next we need to convert that to a 2-D array of each root (x) and it's
    %distance at each timepoint (y)
    
    all_root_dist = {};
    
    %Next we do the math to calculate the distance based on the center
    for i = 1:root_num
        for j = 1:time
            c_dist = 0;
            for k = 2:h
                if isempty(root_overwrite{k,i,j})
                    all_root_dist{j,i} = 0;
                    break
                end
                c_dist = c_dist + (sqrt(((root_overwrite{k,i,j} - root_overwrite{(k-1),i,j})^2)+1));
            end
            all_root_dist{j,i} = c_dist;
        end
    end
    
    %Next we remove any roots that jump in length due to algorithm errors
    to_remove = [];
    for i = 1:root_num
        if (sum(diff(cell2mat(all_root_dist(:,i))) > 20) > 0)
            %checks if there is a jump greater than 20
            %save i value for root to remove
            to_remove = [to_remove i];
            fprintf('JUMP: %d\n', i);
        elseif (nnz(~diff(cell2mat(all_root_dist(:,i)))) > 17)
            %checks if there are more than 17 timesteps where the length
            %does not change and saves i for root to remove - total steps not
            %in a row is what counts
            fprintf('STUCK: %d\n', i);
            to_remove = [to_remove i];
        end
    end
    
    %We then subset the cell array using the list previously created
    for i = length(to_remove):-1:1
        all_root_dist(:,to_remove(i)) = [];
        root_overwrite(:,to_remove(i),:) = [];
    end
    
    xfold_all_root_dist{n} = all_root_dist;
    xfold_all_root_overwrite{n} = root_overwrite;
    
    final_dim = size(all_root_dist);
    final_root_num = final_dim(2);
    
    all_root_rate = {};
    all_root_length = {};
    
    for i = 1:final_root_num
        for j = 2:time
            all_root_length{j,i} = all_root_dist{j,i}-all_root_dist{1,i};
            all_root_rate{j,i} = all_root_dist{j,i}-all_root_dist{j-1,i};
        end
    end
    
    xfold_all_root_rate{n} = all_root_rate;
    xfold_all_root_length{n} = all_root_length;
    
    clear all_root_dist root_overwrite all_root_rate all_root_length
    
end

%Change to specified directory to output files and videos
cd(output_path);


for h = 1:length(xfold_t_step_proc)
    %Outer loop for each XY folder
    
    %Get variables to use in inner loops from the dataset
    [hh,root_num,time] = size(xfold_all_root_data{h});
    
    raw_frames = xfold_t_step{h};
    proc_frames = xfold_t_step_proc{h};
    
  
    
end


%Plot the length values and save jpg
figure;
hold on
for i = 1:length(xfold_all_root_length)
    all_root_length = xfold_all_root_length{i};
    all_root_dist = xfold_all_root_dist{i};
    final_dim = size(all_root_dist);
    final_root_num = final_dim(2);
    
    for j = 1:final_root_num
        plot(cell2mat(all_root_length(:,j)));
    end
end
title('Root Growth from T=0');
xlabel('Time Step');
ylabel('Center Line Distance in Pixels');
saveas(gcf,strcat(output_name, '.jpg'))
hold off;
close all;


%Plot the average length values and save jpg
figure;
hold on
for i = 1:length(xfold_all_root_length)
    all_root_length = xfold_all_root_length{i};
    all_root_dist = xfold_all_root_dist{i};
    final_dim = size(all_root_dist);
    final_root_num = final_dim(2);
    
    plot(mean(cell2mat(all_root_length(:,:))'), 'DisplayName', gene_cond_cell{1,i});
    
end
legend('Location', 'northwest');
title('Average Root Growth from T=0');
xlabel('Time Step');
ylabel('Center Line Distance in Pixels');
saveas(gcf,strcat(output_name, '_average', '.jpg'))
hold off;
close all;

export_matrix = [];

for h = 1:length(xfold_all_root_length)
    all_root_length = xfold_all_root_length{h};
    all_root_dist = xfold_all_root_dist{h};
    final_dim = size(all_root_dist);
    final_root_num = final_dim(2);
    
    split_gene = strsplit(gene_cond_cell{1,h}, "_");
    
    sub_matrix = {};
    
    for i = 1:final_root_num
        for j = 1:length(t_step_proc)
            
            %Date in column 1
            sub_matrix{((i-1)*length(t_step_proc))+j,1} = date;
            %Experiment Number in column 2
            sub_matrix{(((i-1)*length(t_step_proc))+j),2} = experiment_num;
            %Genotype in column 3
            sub_matrix{(((i-1)*length(t_step_proc))+j),3} = split_gene{1};
            %Condition in column 4
            sub_matrix{(((i-1)*length(t_step_proc))+j),4} = split_gene{2};
            %Root number in column 5
            sub_matrix{(((i-1)*length(t_step_proc))+j),5} = i;
            %Timestep in column 6
            sub_matrix{(((i-1)*length(t_step_proc))+j),6} = j*5;
            
            
            if isempty(all_root_length{j,i})
                sub_matrix{(((i-1)*length(t_step_proc))+j),7} = 0;
            else
                sub_matrix{(((i-1)*length(t_step_proc))+j),7} = all_root_length{j,i};
            end
        end
    end
    
    export_matrix = vertcat(export_matrix, sub_matrix);
    
end

T = array2table(export_matrix);

if ~isempty(T) %Only tries to save the table if it exists - prevents error cases from crashing the entire code
    T.Properties.VariableNames = {'Date' 'EXP' 'Genotype' 'Condition' 'Root_Num' 'Timestep_sec' 'Measure'};
    writetable(T, strcat(output_name, '.xlsx'), 'Sheet', 1);
else
    fprintf('\nAlgorithm failed to detect any roots successfully.\n');
end

toc;
