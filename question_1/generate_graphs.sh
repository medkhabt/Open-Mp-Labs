#! /bin/bash

# Create the necessary folders  
rm -rf .temp_* 2>/dev/null
temp_folder=$(echo ".temp_$RANDOM")
mkdir target 2>/dev/null 
mkdir stats 2>/dev/null
mkdir stats/csv stats/dat 2>/dev/null
mkdir graphs 2>/dev/null
## GNUPLOT files 
## for the dem files that plots the graph
mkdir graphs/.generator 2>/dev/null
## for the dat files that stores the data in the right form for gnuplot before being ploted. 
mkdir graphs/.generator/.data 2>/dev/null
mkdir $temp_folder 2>/dev/null

# Remove training intermediate data from old execution or wrong execution of the script, just to be safe.

rm target/* 2>/dev/null
rm stats/csv/* 2>/dev/null 
rm stats.csv 2>/dev/null
rm graphs/.generator/* 2>/dev/null
rm graphs/.generator/.data/* 2>/dev/null
rm graphs/* 2>/dev/null
# TODO whatchout, in case running multiple scripts, maybe create a folder for this bash command 
# TODO URGENT : We are now doing Strong scaling analysis.
# ls with p so folder will have a slash at the end, and -l so we can have a file/folder per line for awk , grep -v to remove the folders.
ls src/parallel -pl | grep -v / | awk '{if(NR-1 > 0) print $NF }' > $temp_folder/.parallel_files_to_compile.tmp
ls src/sequential -pl | grep -v / | awk '{if(NR-1 > 0) print $NF }' > $temp_folder/.sequential_files_to_compile.tmp

# Compilation of the parallel files.
while IFS= read -r line 
do 
   target_file=$(echo $line | sed 's/.cpp//')
   g++ -o target/$target_file src/parallel/$line src/stats/generate_stats.cpp -fopenmp -O3 -march=native
   echo "$target_file">> $temp_folder/.files_to_run.tmp
done < $temp_folder/.parallel_files_to_compile.tmp
# Compilation of the sequential files.
while IFS= read -r line 
do 
   target_file=$(echo $line | sed 's/.cpp//')
   g++ -o target/$target_file src/sequential/$line src/stats/generate_stats.cpp -O3 -march=native
   echo "$target_file">> $temp_folder/.files_to_run.tmp
done < $temp_folder/.sequential_files_to_compile.tmp

echo "End of compilation" 

# Create test cases and run them 
num_steps=(1000000 100000000 10000000000 1000000000000)
num_cores=(1 2 4 8)
num_repeats=2
while IFS= read -r line 
do
    echo "*********** file: $line *******"
    # wait $! 
    echo "**********************************"

    for step in ${num_steps[@]}; do 
	for core in ${num_cores[@]}; do 
	    for ((repeat=0; repeat<=$num_repeats; repeat++)) ; do 
		echo "num_repeats is ${num_repeats}"
		echo "step ${step}, core ${core}, repeat ${repeat}"
		let "index = $step * 4 * 10 +  $core * 10 + $repeat"
		./target/${line} -C ${core} -N ${step} &
		pids[${index}]=$! 
# does it work also for the sequential target 
	    done # end repeat loop 
	done # end core loop 
    done # end step loop 
# TODO block here before change the name of the stats.csv ( acutally they were no stats generated as the first execution didn't finish when arriving here so the stats.csv wasn't created.
    for pid in ${pids[*]};do 
	wait $pid 
    done 
    mv stats.csv stats/csv/${line}_stats.csv
    # wait $!
    echo "End tests"

done < $temp_folder/.files_to_run.tmp
# Create graphs "gnuplot"

## Create dat files. changing the , by spaces 
ls stats/csv -pl | grep -v / | awk '{if(NR-1 > 0) print $NF }' > $temp_folder/.csv_stat_files.tmp

while IFS= read -r line 
do 
sed 's/,/ /g' stats/csv/$line | awk '{
    key = $2 + 50 * $1; 
    sum[key]+=$3 ; N[key]++; cores[key]=$1; num_repeats[key]=$2; 
} END {
    for (k in sum) {
	avg = sum[k]/N[k];
	printf "%s %s %f\n", cores[k], num_repeats[k], avg;
    }
}'> .tmp_dat_$line
 awk '
{
    if($1==1){
	start[$2]=$3
    }
}
 END { 
	while(getline < FILENAME){
	   print($1, $2, start[$2]/$3)
	}
}' .tmp_dat_$line |  sort -k2,2 -k1 > graphs/.generator/.data/${line}_speed_up.dat   







echo -e  "set term png size 1280,720\nset output '../${line}__speed_up.png'\n#set logscale y\n set key left top" >> graphs/.generator/generate_${line}_speed_up_plot.dem

echo -n "plot " >> graphs/.generator/generate_${line}_speed_up_plot.dem
    for step in ${num_steps[@]}; do 
	# Watch out, it depends on the placement of the dem file. The script expects the dem file to be in the graphs/.generator/
	echo -n "\".data/${line}_speed_up.dat\" using 1:(\$2==$step ? \$3:NaN) title \"n_iterations: $step\" with lp,"  >> graphs/.generator/generate_${line}_speed_up_plot.dem

# TODO remove the sequential case from the geneartion of the graph ? 
    cd graphs/.generator
    echo " the line is $line"
    gnuplot generate_${line}_speed_up_plot.dem
    # Get back to the root folder.
    cd ../..
    done
echo 
done < $temp_folder/.csv_stat_files.tmp

echo "End the generation of graphs"

# CREATION OF the dem file to get ploted.

# all what comes before the plot 
# the actual plot 
# Remove the temp files 
rm .[!.]*tmp
