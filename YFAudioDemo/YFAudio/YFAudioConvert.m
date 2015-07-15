
/***********************************************************
 //  YFAudioConvert.m
 //  Mao Kebing
 //  Created by mac on 13-7-25.
 //  Copyright (c) 2013 Eduapp. All rights reserved.
 ***********************************************************/

#import "YFAudioConvert.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "interf_dec.h"
#include "interf_enc.h"

typedef struct
{
	char chChunkID[4];
	int nChunkSize;
}XCHUNKHEADER;

typedef struct
{
	short nFormatTag;
	short nChannels;
	int nSamplesPerSec;
	int nAvgBytesPerSec;
	short nBlockAlign;
	short nBitsPerSample;
}WAVEFORMAT;

typedef struct
{
	short nFormatTag;
	short nChannels;
	int nSamplesPerSec;
	int nAvgBytesPerSec;
	short nBlockAlign;
	short nBitsPerSample;
	short nExSize;
}WAVEFORMATX;

typedef struct
{
	char chRiffID[4];
	int nRiffSize;
	char chRiffFormat[4];
}RIFFHEADER;

typedef struct
{
	char chFmtID[4];
	int nFmtSize;
	WAVEFORMAT wf;
}FMTBLOCK;


#define AMR_MAGIC_NUMBER "#!AMR\n"

#define PCM_FRAME_SIZE 160 // 8khz 8000*0.02=160
#define MAX_AMR_FRAME_SIZE 32
#define AMR_FRAME_COUNT_PER_SECOND 50

typedef UInt64 u64;
typedef SInt64 s64;
typedef UInt32 u32;
typedef UInt16 u16;
typedef UInt8 u8;
int YFAmrEncodeMode[] = {4750, 5150, 5900, 6700, 7400, 7950, 10200, 12200}; // amr 编码方式

u16 readUInt16(char* bis) {
	u16 result = 0;
	result += ((u16)(bis[0])) << 8;
	result += (u8)(bis[1]);
	return result;
}

u32 readUint32(char* bis) {
	u32 result = 0;
	result += ((u32) readUInt16(bis)) << 16;
	bis+=2;
	result += readUInt16(bis);
	return result;
}

s64 readSint64(char* bis) {
	s64 result = 0;
	result += ((u64) readUint32(bis)) << 32;
	bis+=4;
	result += readUint32(bis);
	return result;
}

NSData * fuckAndroid3GP(NSData *data) {
	u32 size = 0;
	u32 type =0;
	u32 boxSize =0;
	
	char AMR_MAGIC_HEADER[6] = {0x23, 0x21, 0x41, 0x4d, 0x52, 0x0a};
	
	if (data.length<50) {
		return data;
	}
	char *bis = (char *)[data bytes];
	
	size = readUint32(bis);
	boxSize += 4;
	bis+=4;
	type = readUint32(bis);
	boxSize += 4;
	bis+=4;
	if (type!=0x66747970) {
		return data;
	}
	
	boxSize += 4;
	bis+=4;
	boxSize += 4;
	bis+=4;
	int remainSize = (int)(size - boxSize);
	if (remainSize > 0) {
		for (int i = 0; i < remainSize / 4; i++) {
			readUint32(bis);
			bis+=4;
		}
	}
	
	boxSize = 0;
	size = readUint32(bis);
	boxSize += 4;
	bis+=4;
	boxSize += 4;
	bis+=4;
	
	int rawAmrDataLength=(size - boxSize);
	int fullAmrDataLength = 6 + rawAmrDataLength;
	NSMutableData *amrData = [[NSMutableData alloc]initWithCapacity:fullAmrDataLength];
	[amrData appendBytes:AMR_MAGIC_HEADER length:6];
	[amrData appendBytes:bis length:rawAmrDataLength];
	
	return amrData;
}


#pragma mark - Decode

const int myround(const double x)
{
	return((int)(x+0.5));
}

// 根据帧头计算当前帧大小
int caclAMRFrameSize(unsigned char frameHeader)
{
	int mode;
	int temp1 = 0;
	int temp2 = 0;
	int frameSize;
	
	temp1 = frameHeader;
	
	// 编码方式编号 = 帧头的3-6位
	temp1 &= 0x78; // 0111-1000
	temp1 >>= 3;
	
	mode = YFAmrEncodeMode[temp1];
	
	// 计算amr音频数据帧大小
	// 原理: amr 一帧对应20ms，那么一秒有50帧的音频数据
	temp2 = myround((double)(((double)mode / (double)AMR_FRAME_COUNT_PER_SECOND) / (double)8));
	
	frameSize = myround((double)temp2 + 0.5);
	return frameSize;
}

// 读第一个帧 - (参考帧)
// 返回值: 0-出错; 1-正确
int ReadAMRFrameFirstData(char* fpamr,int pos,int maxLen, unsigned char frameBuffer[], int* stdFrameSize, unsigned char* stdFrameHeader)
{
	int nPos = 0;
	// 先读帧头
	stdFrameHeader[0] = fpamr[pos];nPos++;
	if (pos+nPos >= maxLen) {
		return 0;
	}
	
	// 根据帧头计算帧大小
	*stdFrameSize = caclAMRFrameSize(*stdFrameHeader);
	
	// 读首帧
	frameBuffer[0] = *stdFrameHeader;
	if ((*stdFrameSize-1)*sizeof(unsigned char)<=0) {
		return 0;
	}
	
	memcpy(&(frameBuffer[1]), fpamr+pos+nPos, (*stdFrameSize-1)*sizeof(unsigned char));
	nPos += (*stdFrameSize-1)*sizeof(unsigned char);
	if (pos+nPos >= maxLen) {
		return 0;
	}
	
	return nPos;
}

// 返回值: 0-出错; 1-正确
int ReadAMRFrameData(char* fpamr,int pos,int maxLen, unsigned char frameBuffer[], int stdFrameSize, unsigned char stdFrameHeader)
{
	int nPos = 0;
	unsigned char frameHeader; // 帧头
	
	// 读帧头
	// 如果是坏帧(不是标准帧头)，则继续读下一个字节，直到读到标准帧头
	while(1)
	{
		if (pos+nPos >=maxLen) {
			return 0;
		}
		frameHeader = fpamr[pos+nPos]; nPos++;
		if (frameHeader == stdFrameHeader) break;
	}
	
	// 读该帧的语音数据(帧头已经读过)
	frameBuffer[0] = frameHeader;
	if ((stdFrameSize-1)*sizeof(unsigned char)<=0) {
		return 0;
	}
	memcpy(&(frameBuffer[1]), fpamr+pos+nPos, (stdFrameSize-1)*sizeof(unsigned char));
	nPos += (stdFrameSize-1)*sizeof(unsigned char);
	if (pos+nPos >= maxLen) {
		return 0;
	}
	
	return nPos;
}

void WriteWAVEHeader(NSMutableData* fpwave, int nFrame)
{
	char tag[10] = "";
	
	// 1. 写RIFF头
	RIFFHEADER riff;
	strcpy(tag, "RIFF");
	memcpy(riff.chRiffID, tag, 4);
	riff.nRiffSize = 4                                     // WAVE
	+ sizeof(XCHUNKHEADER)               // fmt
	+ sizeof(WAVEFORMATX)           // WAVEFORMATX
	+ sizeof(XCHUNKHEADER)               // DATA
	+ nFrame*160*sizeof(short);    //
	strcpy(tag, "WAVE");
	memcpy(riff.chRiffFormat, tag, 4);
	[fpwave appendBytes:&riff length:sizeof(RIFFHEADER)];
	
	// 2. 写FMT块
	XCHUNKHEADER chunk;
	WAVEFORMATX wfx;
	strcpy(tag, "fmt ");
	memcpy(chunk.chChunkID, tag, 4);
	chunk.nChunkSize = sizeof(WAVEFORMATX);
	[fpwave appendBytes:&chunk length:sizeof(XCHUNKHEADER)];
	memset(&wfx, 0, sizeof(WAVEFORMATX));
	wfx.nFormatTag = 1;
	wfx.nChannels = 1; // 单声道
	wfx.nSamplesPerSec = 8000; // 8khz
	wfx.nAvgBytesPerSec = 16000;
	wfx.nBlockAlign = 2;
	wfx.nBitsPerSample = 16; // 16位
	//fwrite(&wfx, 1, sizeof(WAVEFORMATX), fpwave);
	[fpwave appendBytes:&wfx length:sizeof(WAVEFORMATX)];
	
	// 3. 写data块头
	strcpy(tag, "data");
	memcpy(chunk.chChunkID, tag, 4);
	chunk.nChunkSize = nFrame*160*sizeof(short);
	[fpwave appendBytes:&chunk length:sizeof(XCHUNKHEADER)];
	
}

NSData* YFDecodeAMRToWAVE(NSData* data) {
	void * destate;
	int nFrameCount = 0;
	int stdFrameSize;
	int nTemp;
	unsigned char stdFrameHeader;
	
	unsigned char amrFrame[MAX_AMR_FRAME_SIZE];
	short pcmFrame[PCM_FRAME_SIZE];
	
	if (data.length<=0) {
		return nil;
	}
	
	char* rfile = (char *)[data bytes];
	int maxLen = (int)[data length];
	int pos = 0;
	
	//有可能是android 3gp格式
	if (strncmp(rfile, AMR_MAGIC_NUMBER, strlen(AMR_MAGIC_NUMBER)))
	{
		data = fuckAndroid3GP(data);
	}
	
	rfile = (char *)[data bytes];
	// 检查amr文件头
	if (strncmp(rfile, AMR_MAGIC_NUMBER, strlen(AMR_MAGIC_NUMBER)))
	{
		return nil;
	}
	
	pos += strlen(AMR_MAGIC_NUMBER);
	// 创建并初始化WAVE文件
	
	NSMutableData* fpwave = [NSMutableData data];
	
	/* init decoder */
	destate = Decoder_Interface_init();
	
	// 读第一帧 - 作为参考帧
	memset(amrFrame, 0, sizeof(amrFrame));
	memset(pcmFrame, 0, sizeof(pcmFrame));
	
	nTemp = ReadAMRFrameFirstData(rfile,pos,maxLen, amrFrame, &stdFrameSize, &stdFrameHeader);
	if (nTemp==0) {
		Decoder_Interface_exit(destate);
		return data;
	}
	pos += nTemp;
	
	// 解码一个AMR音频帧成PCM数据
	Decoder_Interface_Decode(destate, amrFrame, pcmFrame, 0);
	nFrameCount++;
	[fpwave appendBytes:pcmFrame length:PCM_FRAME_SIZE*sizeof(short)];
	
	
	// 逐帧解码AMR并写到WAVE文件里
	while(1)
	{
		memset(amrFrame, 0, sizeof(amrFrame));
		memset(pcmFrame, 0, sizeof(pcmFrame));
		nTemp = ReadAMRFrameData(rfile,pos,maxLen, amrFrame, stdFrameSize, stdFrameHeader);
		if (!nTemp) {break;}
		pos += nTemp;
		
		// 解码一个AMR音频帧成PCM数据 (8k-16b-单声道)
		Decoder_Interface_Decode(destate, amrFrame, pcmFrame, 0);
		nFrameCount++;
		[fpwave appendBytes:pcmFrame length:PCM_FRAME_SIZE*sizeof(short)];
	}
	Decoder_Interface_exit(destate);
	
	// 重写WAVE文件头
	NSMutableData *desData = [NSMutableData data];
	WriteWAVEHeader(desData, nFrameCount);
	[desData appendData:fpwave];
	
	return desData;
}


#pragma mark Encode
// 从WAVE文件读一个完整的PCM音频帧
// 返回值: 0-错误 >0: 完整帧大小
int ReadPCMFrameData(short speech[], char* fpwave, int nChannels, int nBitsPerSample)
{
	int nRead = 0;
	int x = 0, y=0;
	
	// 原始PCM音频帧数据
	unsigned char  pcmFrame_8b1[PCM_FRAME_SIZE];
	unsigned char  pcmFrame_8b2[PCM_FRAME_SIZE<<1];
	unsigned short pcmFrame_16b1[PCM_FRAME_SIZE];
	unsigned short pcmFrame_16b2[PCM_FRAME_SIZE<<1];
	
	nRead = (nBitsPerSample/8) * PCM_FRAME_SIZE*nChannels;
	if (nBitsPerSample==8 && nChannels==1)
	{
		memcpy(pcmFrame_8b1,fpwave,nRead);
		for(x=0; x<PCM_FRAME_SIZE; x++)
		{
			speech[x] =(short)((short)pcmFrame_8b1[x] << 7);
		}
	}
	else
		if (nBitsPerSample==8 && nChannels==2)
		{
			memcpy(pcmFrame_8b2,fpwave,nRead);
			
			for( x=0, y=0; y<PCM_FRAME_SIZE; y++,x+=2 )
			{
				// 1 - 取两个声道之左声道
				speech[y] =(short)((short)pcmFrame_8b2[x+0] << 7);
				// 2 - 取两个声道之右声道
				//speech[y] =(short)((short)pcmFrame_8b2[x+1] << 7);
				// 3 - 取两个声道的平均值
				//ush1 = (short)pcmFrame_8b2[x+0];
				//ush2 = (short)pcmFrame_8b2[x+1];
				//ush = (ush1 + ush2) >> 1;
				//speech[y] = (short)((short)ush << 7);
			}
		}
		else
			if (nBitsPerSample==16 && nChannels==1)
			{
				memcpy(pcmFrame_16b1,fpwave,nRead);
				
				for(x=0; x<PCM_FRAME_SIZE; x++)
				{
					speech[x] = (short)pcmFrame_16b1[x+0];
				}
			}
			else
				if (nBitsPerSample==16 && nChannels==2)
				{
					memcpy(pcmFrame_16b2,fpwave,nRead);
					
					for( x=0, y=0; y<PCM_FRAME_SIZE; y++,x+=2 )
					{
						speech[y] = (short)((int)((int)pcmFrame_16b2[x+0] + (int)pcmFrame_16b2[x+1])) >> 1;
					}
				}
	
	// 如果读到的数据不是一个完整的PCM帧, 就返回0
	return nRead;
}

// WAVE音频采样频率是8khz
// 音频样本单元数 = 8000*0.02 = 160 (由采样频率决定)
// 声道数 1 : 160
//        2 : 160*2 = 320
// bps决定样本(sample)大小
// bps = 8 --> 8位 unsigned char
//       16 --> 16位 unsigned short
NSData* EncodePCMToAMR(char* data, int maxLen,int nChannels, int nBitsPerSample)
{
	char* oldBuf = data;
	/* input speech vector */
	short speech[160];
	
	/* counters */
	int byte_counter, frames = 0, bytes = 0;
	
	/* pointer to encoder state structure */
	void *enstate;
	
	/* requested mode */
	enum Mode req_mode = MR122;
	int dtx = 0;
	
	/* bitstream filetype */
	unsigned char amrFrame[MAX_AMR_FRAME_SIZE];
	
	NSMutableData* out = [[NSMutableData alloc]init];
	/* write magic number to indicate single channel AMR file storage format */
	[out appendBytes:AMR_MAGIC_NUMBER length:strlen(AMR_MAGIC_NUMBER)];
	
	enstate = Encoder_Interface_init(dtx);
	
	while(1)
	{
		// read one pcm frame
		if ((data-oldBuf+320)>maxLen) {
			break;
		}
		int nRead = ReadPCMFrameData(speech, data, nChannels, nBitsPerSample);
		data += nRead;
		
		
		frames++;
		
		/* call encoder */
		byte_counter = Encoder_Interface_Encode(enstate, req_mode, speech, amrFrame, 0);
		
		bytes += byte_counter;
		[out appendBytes:amrFrame length:byte_counter];
	}
	
	Encoder_Interface_exit(enstate);
	
	return out;
}


int SkipCaffHead(char* buf){
	
	if (!buf) {
		return 0;
	}
	char* oldBuf = buf;
	u32 mFileType = readUint32(buf);
	if (0x63616666!=mFileType) {
		return 0;
	}
	buf+=4;
	
	buf+=2;
	buf+=2;
	
	//desc free data
	u32 magics[3] = {0x64657363,0x66726565,0x64617461};
	for (int i=0; i<3; ++i) {
		u32 mChunkType = readUint32(buf);buf+=4;
		if (magics[i]!=mChunkType) {
			return 0;
		}
		
		u32 mChunkSize = (u32)readSint64(buf);buf+=8;
		if (mChunkSize<=0) {
			return 0;
		}
		if (i==2) {
			return (int)(buf-oldBuf);
		}
		buf += mChunkSize;
		
	}
	
	return 1;
}


@implementation YFAudioConvert


#pragma mark ===== Class Api==================
+ (NSData*) amrDataFromWaveData:(NSData *)data
{
	if (data==nil || data.length == 0)
	{
		return nil;
	}
	
	int nPos  = 0;
	char* buf = (char *)[data bytes];
	int maxLen = (int)[data length];
	
	
	nPos += SkipCaffHead(buf);
	if (nPos>=maxLen) {
		return nil;
	}
	
	//这时取出来的是纯pcm数据
	buf += nPos;
	
	return EncodePCMToAMR(buf,maxLen- nPos,1,16);
}
+ (NSData*) wavDataFromAmrData:(NSData *)data
{
	void * destate;
	int nFrameCount = 0;
	int stdFrameSize;
	int nTemp;
	unsigned char stdFrameHeader;
	
	unsigned char amrFrame[MAX_AMR_FRAME_SIZE];
	short pcmFrame[PCM_FRAME_SIZE];
	
	if (data.length<=0) {
		return nil;
	}
	
	char* rfile = (char *)[data bytes];
	int maxLen = (int)[data length];
	int pos = 0;
	
	//有可能是android 3gp格式
	if (strncmp(rfile, AMR_MAGIC_NUMBER, strlen(AMR_MAGIC_NUMBER)))
	{
		data = fuckAndroid3GP(data);
	}
	
	rfile = (char *)[data bytes];
	// 检查amr文件头
	if (strncmp(rfile, AMR_MAGIC_NUMBER, strlen(AMR_MAGIC_NUMBER)))
	{
		return nil;
	}
	
	pos += strlen(AMR_MAGIC_NUMBER);
	// 创建并初始化WAVE文件
	
	NSMutableData* fpwave = [NSMutableData data];
	
	/* init decoder */
	destate = Decoder_Interface_init();
	
	// 读第一帧 - 作为参考帧
	memset(amrFrame, 0, sizeof(amrFrame));
	memset(pcmFrame, 0, sizeof(pcmFrame));
	
	nTemp = ReadAMRFrameFirstData(rfile,pos,maxLen, amrFrame, &stdFrameSize, &stdFrameHeader);
	if (nTemp==0) {
		Decoder_Interface_exit(destate);
		return data;
	}
	pos += nTemp;
	
	// 解码一个AMR音频帧成PCM数据
	Decoder_Interface_Decode(destate, amrFrame, pcmFrame, 0);
	nFrameCount++;
	[fpwave appendBytes:pcmFrame length:PCM_FRAME_SIZE*sizeof(short)];
	
	
	// 逐帧解码AMR并写到WAVE文件里
	while(1)
	{
		memset(amrFrame, 0, sizeof(amrFrame));
		memset(pcmFrame, 0, sizeof(pcmFrame));
		nTemp = ReadAMRFrameData(rfile,pos,maxLen, amrFrame, stdFrameSize, stdFrameHeader);
		if (!nTemp) {break;}
		pos += nTemp;
		
		// 解码一个AMR音频帧成PCM数据 (8k-16b-单声道)
		Decoder_Interface_Decode(destate, amrFrame, pcmFrame, 0);
		nFrameCount++;
		[fpwave appendBytes:pcmFrame length:PCM_FRAME_SIZE*sizeof(short)];
	}
	Decoder_Interface_exit(destate);
	
	// 重写WAVE文件头
	NSMutableData *desData = [NSMutableData data];
	WriteWAVEHeader(desData, nFrameCount);
	[desData appendData:fpwave];
	
	return desData;
}


#pragma mark ========Other Api================






@end
