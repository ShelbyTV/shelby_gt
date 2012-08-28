#ifndef __CVECTOR_H__
#define __CVECTOR_H__

#ifdef __cplusplus
extern "C" {
#endif

typedef struct cvectorStruct *cvector;

/*
 * < should return -1
 * = should return 0
 * > should return 1
 */
typedef int (*cvectorCompareElementCallback)(void *, void *);

cvector cvectorAlloc(const unsigned int elementSize);
void cvectorFree(cvector vec);

unsigned int cvectorCount(const cvector vec);
unsigned int cvectorElementSize(const cvector vec);

void cvectorAddElement(cvector vec, const void *element);
void *cvectorGetElement(const cvector vec, const unsigned int index);

void cvectorSort(cvector vec, cvectorCompareElementCallback compare);

#ifdef __cplusplus
}
#endif

#endif // __CVECTOR_H__
