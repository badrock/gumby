#!/usr/bin/env python
import sys
import os
import glob
import re
from sys import argv


# parses the ledbat log of each libswift client
def parse_stderr(logDir, header, seedersfile, leechersfile):

    stderr_files = [ f for f in os.listdir(logDir) if f.endswith('.err') ]
    print logDir, header, seedersfile
    sfile = open(seedersfile, 'a')
    lfile = open(leechersfile, 'a')
    
    for s in stderr_files:
    
        if s.startswith('seeder'):
            try:
                fl = open( os.path.join( logDir, s), 'r' )
                for line in fl:
                    if not line.startswith('time'):
                        split = line.split()
                        sfile.write( "{0} {1} {2} {3} {4} {5}\n".format( split[0], header, s.split('.')[0], split[1], split[2], split[3]) )
            finally:
                try:
                    fl.close()
                except Exception:
                    pass
        else:
            try:
                fl = open( os.path.join( logDir, s), 'r' )
                for line in fl:
                    if not line.startswith('time'):
                        split = line.split()
                        lfile.write( "{0} {1} {2} {3} {4} {5}\n".format( split[0], header, s.split('.')[0], split[1], split[2], split[3]) )
            finally:
                try:
                    fl.close()
                except Exception:
                    pass

    try:
        if sfile:
            sfile.close()
        if lfile:
            lfile.close()
    except Exception:
        pass




# checks the current dir structure 
def check_dirs(inputDir, outputDir):
    
    # change if the project name changes!
    project_name = re.compile("GUMBY_")
    
    # check input dir
    if not os.path.exists( inputDir ):
        print >> sys.stderr, "Please provide a good input directory"
        return
     # check input dir
    if not os.path.exists( outputDir ):
        print >> sys.stderr, "Please provide a good output directory"
        return

    if outputDir == inputDir and os.path.exists( os.path.join(outputDir,"output") ):
        outputDir = os.path.join(outputDir,"output")
        
    dirs = [ d for d in os.listdir(inputDir) if os.path.isdir( os.path.join(inputDir, d) ) and project_name.match(d) ]
    
    if len(dirs) == 0:
        print >> sys.stderr, "No experiment directory found!"
        return
    
    params_len = len(dirs[0].split(','))
    params = [[] for i in range(params_len)]

    # create an array of parameters
    for d in dirs:
        values = d.split(',')
        idx = 0
        for v in values:        
            params[idx].append(v)
            idx += 1
        
    # remove unchanged parameters
    for p in params:
        try:
            iterator = iter(p)
            first = next(iterator)
            if all(first == rest for rest in iterator):
                params.remove(p)  
        except StopIteration:
            pass
             
    seeders_file = os.path.join(outputDir, 'seeders.err')
    sfile = open( seeders_file, 'w')
    sfile.write( "time experiment client percent upload download\n" )
    sfile.close()
    
    leechers_file = os.path.join(outputDir, 'leechers.err')
    lfile = open( leechers_file, 'w')
    lfile.write( "time experiment client percent upload download\n" )
    lfile.close()
    
    idx = 0
    for d in dirs:
        # input file
        exp_name = ''
        for p in list(p[idx] for p in params):
            exp_name += p[5:] 
        parse_stderr( os.path.join(inputDir, d, 'output'), exp_name, seeders_file, leechers_file )
        idx +=1

    



if __name__ == "__main__":
    if len(argv) < 3:
        print >> sys.stderr, "Usage: %s <input-directory> <output-directory>" % (argv[0])
        print >> sys.stderr, "Got:", argv

        exit(1)

    check_dirs(argv[1], argv[2])
    
