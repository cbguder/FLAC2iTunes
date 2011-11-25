//
//  FLACDecoder.m
//  FLAC2iTunes
//
//  Created by Can Berk Güder on 23/11/2011.
//  Copyright (c) 2011 CBG. All rights reserved.
//

#import "FLACDecoder.h"
#include "stream_decoder.h"

typedef struct {
	uint32 sampleRate;
	uint16 channels;
	uint16 bitsPerSample;
	uint64 totalSamples;
	FILE *fout;
} FLACDecoderState;

static FLAC__StreamDecoderWriteStatus write_callback(const FLAC__StreamDecoder *decoder, const FLAC__Frame *frame, const FLAC__int32 * const buffer[], void *client_data);
static void metadata_callback(const FLAC__StreamDecoder *decoder, const FLAC__StreamMetadata *metadata, void *client_data);
static void error_callback(const FLAC__StreamDecoder *decoder, FLAC__StreamDecoderErrorStatus status, void *client_data);

static BOOL write_little_endian_uint16(FILE *f, uint16 x);
static BOOL write_little_endian_int16(FILE *f, sint16 x);
static BOOL write_little_endian_uint32(FILE *f, uint32 x);
static BOOL write_iff_headers(FLACDecoderState *state);

BOOL FLACDecodeFile(NSString *src, NSString *dst) {
	FLAC__StreamDecoder *decoder = FLAC__stream_decoder_new();

	if (decoder == NULL) return NO;

	FLAC__stream_decoder_set_md5_checking(decoder, true);

	FLACDecoderState state;
	state.fout = fopen([dst UTF8String], "wb");

	FLAC__StreamDecoderInitStatus init_status = FLAC__stream_decoder_init_file(decoder,
																			   [src UTF8String],
																			   write_callback,
																			   metadata_callback,
																			   error_callback,
																			   &state);

	BOOL ok = NO;

	if(init_status != FLAC__STREAM_DECODER_INIT_STATUS_OK)
		goto exit;

	if (!FLAC__stream_decoder_process_until_end_of_metadata(decoder))
		goto exit;

	if (FLAC__stream_decoder_get_state(decoder) > FLAC__STREAM_DECODER_END_OF_STREAM)
		goto exit;

	if (!write_iff_headers(&state))
		goto exit;

	if (FLAC__stream_decoder_process_until_end_of_stream(decoder)) {
		ok = YES;
	}

exit:

	if (!FLAC__stream_decoder_finish(decoder)) {
		ok = NO;
	}

	FLAC__stream_decoder_delete(decoder);
	fclose(state.fout);

	return ok;
}

#pragma mark - Utility functions

static BOOL write_little_endian_uint16(FILE *f, uint16 x) {
	return fwrite(&x, 1, 2, f) == 2;
}

static BOOL write_little_endian_uint24(FILE *f, uint32 x) {
	return fwrite(&x, 1, 3, f) == 3;
}

static BOOL write_little_endian_uint32(FILE *f, uint32 x) {
	return fwrite(&x, 1, 4, f) == 4;
}

static BOOL write_iff_headers(FLACDecoderState *s) {
	uint16 bytesPerSample = s->bitsPerSample / 8;
	uint16 blockAlign = s->channels * bytesPerSample;
	uint32 byteRate = s->sampleRate * blockAlign;
	uint32 totalSize = (uint32)(s->totalSamples * blockAlign);

	FILE *f = s->fout;

	if (fwrite("RIFF", 1, 4, f) < 4)
		return NO;

	if (!write_little_endian_uint32(f, totalSize + 36))
		return NO;

	if (fwrite("WAVEfmt ", 1, 8, f) < 8)
		return NO;

	if (!write_little_endian_uint32(f, 16))
		return NO;
	
	if (!write_little_endian_uint16(f, 1))
		return NO;
	
	if (!write_little_endian_uint16(f, s->channels))
		return NO;
	
	if (!write_little_endian_uint32(f, s->sampleRate))
		return NO;
	
	if (!write_little_endian_uint32(f, byteRate))
		return NO;
	
	if (!write_little_endian_uint16(f, blockAlign))
		return NO;
	
	if (!write_little_endian_uint16(f, s->bitsPerSample))
		return NO;
	
	if (fwrite("data", 1, 4, f) < 4)
		return NO;
	
	if (!write_little_endian_uint32(f, totalSize))
		return NO;

	return YES;
}

#pragma mark - Callbacks

static FLAC__StreamDecoderWriteStatus write_callback(const FLAC__StreamDecoder *decoder, const FLAC__Frame *frame, const FLAC__int32 * const buffer[], void *client_data) {
	FLACDecoderState *state = (FLACDecoderState *)client_data;
	FILE *f = state->fout;

	if (state->bitsPerSample == 16) {
		for (int i = 0; i < frame->header.blocksize; i++) {
			for (int channel = 0; channel < state->channels; channel++) {
				if (!write_little_endian_uint16(f, buffer[channel][i]))
					return FLAC__STREAM_DECODER_WRITE_STATUS_ABORT;
			}
		}
	} else if (state->bitsPerSample == 24) {
		for (int i = 0; i < frame->header.blocksize; i++) {
			for (int channel = 0; channel < state->channels; channel++) {
				if (!write_little_endian_uint24(f, buffer[channel][i]))
					return FLAC__STREAM_DECODER_WRITE_STATUS_ABORT;
			}
		}
	}

	return FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE;
}

static void metadata_callback(const FLAC__StreamDecoder *decoder, const FLAC__StreamMetadata *metadata, void *client_data) {
	FLACDecoderState *state = (FLACDecoderState *)client_data;

	if(metadata->type == FLAC__METADATA_TYPE_STREAMINFO) {
		state->sampleRate = metadata->data.stream_info.sample_rate;
		state->channels = metadata->data.stream_info.channels;
		state->bitsPerSample = metadata->data.stream_info.bits_per_sample;
		state->totalSamples = metadata->data.stream_info.total_samples;
	}
}

static void error_callback(const FLAC__StreamDecoder *decoder, FLAC__StreamDecoderErrorStatus status, void *client_data) {
}
