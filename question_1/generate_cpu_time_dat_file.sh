#! /bin/bash 

sed 's/,/ /g' stats/csv/$1 | awk '{
    key = $2 + 50 * $1; 
    sum[key]+=$3 ; N[key]++; cores[key]=$1; num_repeats[key]=$2; 
} END {
    for (k in sum) {
	avg = sum[k]/N[k];
	printf "%s %s %f\n", cores[k], num_repeats[k], avg;
    }
}' | sort -k2,2 -k1 > graphs/.generator/.data/${1}.dat   



