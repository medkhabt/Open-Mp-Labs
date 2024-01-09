#! /bin/bash

# Create the necessary folders  
temp_folder=$(echo "temp_$RANDOM")
mkdir target 2>/dev/null 
mkdir stats 2>/dev/null
mkdir stats/csv stats/dat 2>/dev/null
mkdir graphs 2>/dev/null
## GNUPLOT files 
## for the dem files that plots the graph
mkdir graphs/.generator 2>/dev/null
## for the dat files that stores the data in the right form for gnuplot before being ploted. 
mkdir graphs/.generator/.data 2>/dev/null
mkdir temp_folder 2>/dev/null

# Remove training intermediate data from old execution or wrong execution of the script, just to be safe.

rm target/* 2>/dev/null
rm stats/csv/* 2>/dev/null 
rm stats.csv 2>/dev/null
rm graphs/.generator/* 2>/dev/null
rm graphs/.generator/.data/* 2>/dev/null
rm graphs/* 2>/dev/null
# TODO whatchout, in case running multiple scripts, maybe create a folder for this bash command 
rm -rf temp_folder 2>/dev/null
# TODO URGENT : We are now doing Strong scaling analysis.
# ls with p so folder will have a slash at the end, and -l so we can have a file/folder per line for awk , grep -v to remove the folders.
ls src/parallel -pl | grep -v / | awk '{if(NR-1 > 0) print $NF }' > temp_folder/.parallel_files_to_compile.tmp
ls src/sequential -pl | grep -v / | awk '{if(NR-1 > 0) print $NF }' > .sequential_files_to_compile.tmp

# Compilation of the parallel files.
while IFS= read -r line 
do 
   target_file=$(echo $line | sed 's/.cpp//')
   g++ -o target/$target_file src/parallel/$line src/stats/generate_stats.cpp -fopenmp -O3 -march=native
   echo "$target_file">>.files_to_run.tmp
done < .parallel_files_to_compile.tmp
# Compilation of the sequential files.
while IFS= read -r line 
do 
   target_file=$(echo $line | sed 's/.cpp//')
   g++ -o target/$target_file src/sequential/$line src/stats/generate_stats.cpp -O3 -march=native
   echo "$target_file">>.files_to_run.tmp
done < .sequential_files_to_compile.tmp



# Create test cases and run them 
num_steps=(1000000 100000000) #10000000000 1000000000000)
num_cores=(1, 2, 4, 8)
num_repeats=1
while IFS= read -r line 
do
    for step in ${num_steps[@]}; do 
	for core in ${num_cores[@]}; do 
	    for repeat in {0..$num_repeats}; do 
# does it work also for the sequential target 
		./target/${line} -C ${core} -N ${step}
	    done 
	done 
    done 
    mv stats.csv stats/csv/${line}_stats.csv
done < .files_to_run.tmp
#TODO remove this exit 
# Create graphs "gnuplot"

## Create dat files. changing the , by spaces 
ls stats/csv -pl | grep -v / | awk '{if(NR-1 > 0) print $NF }' > .csv_stat_files.tmp

#TODO don't forget the avg when we have more than one repeat, we can just divide the summation of all the cputimes on the number of repeats. before doing any speedup , i would need an association array for the sum of the same iteration and an othe one for the number of occurances. maybe also detect if there are some instances that are not present ( 4 out of 5 , one failed!) . 
while IFS= read -r line 
do 
# we assuem that the file is order, if it isn't it wouldn't work with this implementation.
    sed 's/,/ /g' stats/csv/$line | awk '{if($1==1){start[$2]=$3} print($1,$2,start[$2]/$3)}' > graphs/.generator/.data/${line}_speed_up.dat   
echo -e  "set term png size 1280,720\nset output '../${line}__speed_up.png'\nset logscale y\n set key left top" >> graphs/.generator/generate_${line}_speed_up_plot.dem

echo -n "plot " >> graphs/.generator/generate_${line}_speed_up_plot.dem
    for step in ${num_steps[@]}; do 
	# Watch out, it depends on the placement of the dem file. The script expects the dem file to be in the graphs/.generator/
	echo -n "\".data/${line}_speed_up.dat\" using 1:(\$2==$step ? \$3:NaN) title \"n_iterations: $step\" with lp,"  >> graphs/.generator/generate_${line}_speed_up_plot.dem

# TODO watch out for the last comma, that is effect the plotting ? 	
    cd graphs/.generator
    gnuplot generate_${line}_speed_up_plot.dem
    # Get back to the root folder.
    cd ../..
    done
echo 
done < .csv_stat_files.tmp

# CREATION OF the dem file to get ploted.

# all what comes before the plot 
# the actual plot 
# Remove the temp files 
rm .[!.]*tmp
