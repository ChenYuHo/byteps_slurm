import os
import torch
import argparse
from time import sleep
from random import randint
import time
import random
import numpy
import sys
import byteps.torch as bps
initvalue = 0.01

def gen_data(rank, tensorsize, blocksize, density):
    blocknum = int(tensorsize/blocksize)
    if rank==-1:
        nonzero_bnum=0
    else:
        nonzero_bnum = int(blocknum*density)
    #print(nonzero_bnum, blocknum)
    random.seed(rank)
    #random.seed(0)
    nonzero_blocks = random.sample(range(blocknum), nonzero_bnum)
    #print("nonzero block num:", len(nonzero_blocks))
    data = [0.0]*tensorsize
    for bid in nonzero_blocks:
        idx = bid*blocksize
        while idx<(bid+1)*blocksize:
            data[idx] = initvalue
            idx += 1
    return data

def gen_data_nonoverlap(rank, worldsize, tensorsize, blocksize, density):
    blocknum = int(tensorsize/blocksize)
    if rank==-1:
        nonzero_bnum=0
    else:
        nonzero_bnum = int(blocknum*density)
    start_index = int(rank*(blocknum-nonzero_bnum)/(worldsize-1))
    nonzero_blocks = range(start_index, min(blocknum, start_index+nonzero_bnum))
    #print("nonzero block num:", len(nonzero_blocks))
    data = [0.0]*tensorsize
    for bid in nonzero_blocks:
        idx = bid*blocksize
        while idx<(bid+1)*blocksize:
            data[idx] = initvalue
            idx += 1
    return data

def check_density(tensor, blocksize, tensorsize):
    i=0
    nonzeronum = 0
    while i<tensorsize:
        if tensor[i]!=0.0:
            nonzeronum+=1
        i += blocksize
    return nonzeronum

def get_expected_result(worldsize, tensorsize, blocksize, density, allreduce_times):
    data = [0.0 for i in range(tensorsize)]
    for rank in range(worldsize):
        tmp = gen_data(rank, tensorsize, blocksize, density)
        for i in range(tensorsize):
            data[i] += tmp[i]
    return data

def foo(tensorsize, blocksize, density):
    begin = time.time()
    data = gen_data(bps.rank(), tensorsize, blocksize, density)
    #data = gen_data_nonoverlap(rank, world_size, tensorsize, blocksize, density)
    #print("density :",check_density(data, 256, tensorsize))
    #tensor_data = torch.FloatTensor(data).cuda()
    tensor_data = torch.FloatTensor(data).cuda()
    #tensor_data2 = torch.FloatTensor([1.0]*12).cuda()
    tensor = tensor_data.clone()
    #tensor2 = tensor_data2.clone()
    # group all ranks
    ranks = list(range(bps.size()))
    allreduce_time = []
    extra_time = time.time()-begin
    localtime = numpy.zeros(1)
    globaltime = numpy.zeros(1)
    
    #Warm up
    for step in range(10):
        #print(step)
        sys.stdout.flush()
        bps.push_pull(tensor, name='real')
        tensor = tensor_data.clone()
        #torch.cuda.synchronize()
    #print("Warm up over")
    sys.stdout.flush()
    allreduce_times = 0
    for step in range(10):
        localtime = numpy.zeros(1)
        globaltime = numpy.zeros(1)
        if step%10==0:
            allreduce_times = 0
            tensor = tensor_data.clone()
        allreduce_times += 1
        #if rank==0:
            #print("before: ", tensor[26214380])
        #tensor2 = tensor_data2.clone()
        begin = time.time()
        bps.push_pull(tensor, name='real')
        #torch.cuda.synchronize()
        #dist.all_reduce(tensor2, op=dist.ReduceOp.SUM, group=group)
        #torch.cuda.synchronize()
        localtime[0] = int((time.time()-begin)*1000000)
        #comm.Reduce(localtime, globaltime, MPI.MAX, 0)
        globaltime[0]=localtime[0]
        #if rank==0:
        #    print("after: ", tensor[100])
        if bps.rank()==0:
            #print("after: ", tensor[26214380])
            print("time:"+str(globaltime[0])+";")
            #sys.stdout.flush()
            #allreduce_time.append(globaltime[0])
            #print(step, allreduce_time)
            #with open('./results/bitmap-'+str(tensorsize)+'-'+str(density), 'w+') as f:
            #with open('./results/omnireduce7-'+str(tensorsize)+'-'+str(density), 'w+') as f:
            #    for item in allreduce_time:
            #        f.write(str(item)+'\n')
        #comm.Barrier()

        #tensor = tensor/8
    print('done')
    from pathlib import Path
    open(f'{str(Path.home())}/iamdone-{os.environ.get("SLURM_JOB_ID", "")}', 'a').close()
    #print(tensor)
'''
    print("allreduce times:", allreduce_times)
    print("final check:")
    if rank==0:
        print("gen expected result")
        expected = get_expected_result(world_size, tensorsize, blocksize, density, allreduce_times)
        tensor = tensor.cpu().data.numpy()
        torch.cuda.synchronize() 
        result_value = initvalue*pow(2,allreduce_times)
        for i in range(tensorsize):
            expected_value = expected[i]*pow(world_size, allreduce_times-1)
            if i % 100000==0:
                print("check: ", i, expected_value, tensor[i])
            if abs(tensor[i]-expected_value)>0.1 :
                print("allreduce error: ", expected_value, tensor[i])
                break
 '''
    #if rank==0:
    #    print("final: ", sum(allreduce_time)/len(allreduce_time))
        #print(allreduce_time)

def initialize(tensorsize=26214400, blocksize=256, density=0.5):
    bps.init()
    begin = time.time()
    foo(tensorsize, blocksize, density)
    total_time = time.time()-begin

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--tensor-size', '-t', type=int)
    parser.add_argument('--block-size', '-b', type=int)
    parser.add_argument('--density', '-d', type=float)
    args = parser.parse_args()
    initialize(args.tensor_size, args.block_size, args.density)

if __name__ == '__main__':
    main()
