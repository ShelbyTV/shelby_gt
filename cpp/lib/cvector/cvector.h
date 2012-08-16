#ifndef __CVECTOR_H__
#define __CVECTOR_H__

#ifdef __cplusplus
extern "C" {
#endif

typedef struct cvectorStruct *cvector;

cvector cvectorAlloc(const unsigned int elementSize);
void cvectorFree(cvector vec);

unsigned int cvectorCount(const cvector vec);
unsigned int cvectorElementSize(const cvector vec);

void cvectorAddElement(cvector vec, const void *element);
void *cvectorGetElement(const cvector vec, const unsigned int index);

#ifdef __cplusplus
}
#endif

#endif // __CVECTOR_H__
