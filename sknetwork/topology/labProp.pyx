# distutils: language = c++
# cython: language_level=3
"""
Created on Jun 3, 2020
@author: Julien Simonnet <julien.simonnet@etu.upmc.fr>
@author: Yohann Robert <yohann.robert@etu.upmc.fr>
"""

from typing import Union

import numpy as np
cimport numpy as np

from libcpp.vector cimport vector
from libcpp cimport bool

from libc.stdlib cimport rand, srand

from scipy import sparse

cimport cython

ctypedef np.int_t int_type_t

@cython.boundscheck(False)
@cython.wraparound(False)


#shuffle randomly a numpy array
cdef void shuffle(int[:] arr, int n):
	cdef int temp, i, j;
	for i in range(n-1, 0, -1):
		j = rand() % (i+1)
		temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp
	
cdef np.ndarray[int, ndim=1] fit_core(int n_nodes, int[:] indices, int[:] indptr):
	"""	   Calculates the labels of each nodes using the label propagation algorithm.

	Parameters
	----------
	n_nodes :
		Number of nodes.
	indices :
		CSR format index pointer array of the normalized adjacency matrix.
	indptr :
		CSR format index array of the normalized adjacency matrix.

	Returns
	-------
	 self: :class:`LabelPropagation`
	"""
	
	cdef np.ndarray[int, ndim=1] labels		#array of labels of each nodes
	cdef np.ndarray[int, ndim=1] order		#array of the order in which we will update the labels
	cdef vector[int] nb_labels		#vector giving the number of found labels among the neighbors
	cdef vector[int] lst			#list of found labels
	
	cdef int i, j, k
	cdef int label
	cdef int nb_lab_max		#max number in nb_labels
	cdef int list_size		#number of elements in lst
	
	cdef bool changed = True	#true if a label has been updated
	
	labels = np.arange(n_nodes, dtype=np.int32)			#initializes the array like a range
	order = np.arange(n_nodes, dtype=np.int32)			#initializes another array like a range
	nb_labels.reserve(n_nodes)		#reserve necessary space in another vector
	lst.reserve(n_nodes,)			#reserve space in the vector
	
	for i in range(n_nodes):
		nb_labels[i] = 0
	
	while changed :		#loops until the labels cannot be updated
		shuffle(order, n_nodes)		#chooses another order
		changed = False
		for k in range(n_nodes):
			i = order[k]
			list_size = 0
			
			#updates the label of the node i by looking at the most frequent one among its neighbors
			for j in range(indptr[i], indptr[i+1]):
				label = labels[indices[j]]
				if nb_labels[label] == 0:	#if this is the first time with encounter the label
					lst[list_size] = label
					list_size += 1
					
				nb_labels[label] += 1		#the number of occurence of the label is incremented
			
			nb_lab_max = nb_labels[labels[i]]
			for j in range(list_size):
				label = lst[j]
				if nb_lab_max < nb_labels[label]:	#only if the label is more frequent is it updated
					nb_lab_max = nb_labels[label]
					labels[i] = label
					changed = True
				nb_labels[label] = 0
				
	return labels
		

class LabelPropagation:
	"""Label propagation algorithm.

	* Graphs
	
	Parameters
	----------
	seed:
		Integer used as a seeds, otherwise None is used.
		
	Attributes
	----------
	labels_ : np.ndarray
		Label of each node.

	Example
	-------
	>>> from sknetwork.clustering import LabelPropagation
	>>> from sknetwork.data import karate_club
	>>> propagation = LabelPropagation()
	>>> graph = karate_club(metadata=True)
	>>> adjacency = graph.adjacency
	>>> labels = propagation.fit_transform(adjacency)
	>>> len(set(labels))
	2
	"""
	
	def __init__(self, seed : Union[int, None] = None):
		self.labels_ = None
		self.seed = seed
		
	
	def fit(self, adjacency : sparse.csr_matrix) -> 'LabelPropagation':
		""" Clustering.

		Parameters
		----------
		adjacency:
			Adjacency matrix of the graph.

		Returns
		-------
		 self: :class:`LabelPropagation`
		"""
		if (self.seed is not None):
			srand(self.seed)		#initializes the seed
		
		self.labels_ = fit_core(adjacency.shape[0], adjacency.indices, adjacency.indptr)
		return self
		
		
	def fit_transform(self, *args, **kwargs) -> np.ndarray:
		"""Fit algorithm to the data and return the labels. Same parameters as the ``fit`` method.

		Returns
		-------
		labels : np.ndarray
			Labels.
		"""
		self.fit(*args, **kwargs)
		return self.labels_