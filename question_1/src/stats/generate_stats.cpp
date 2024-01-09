#include <iostream>
#include <fstream>
#include <cmath>
#include <string.h>
#include "generate_stats.h"
void generateStats(const int nb_core, const long num_steps, const double &runtime) {
       //	struct stat buffer; 
	//bool file_exists = stat ( "stats.csv", &buffer ) != 0; 
	std::ofstream stats; 
	stats.open("stats.csv", std::ios_base::app); 


	    stats << nb_core << "," <<  num_steps << "," << runtime << std::endl;
	stats.close();
}
