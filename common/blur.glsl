#ifdef PIXEL

// 3x3 Gaussian kernel (sigma = 1.7)
const float offset_3[3] = float[](0.0000000000, 1.3730788130, 3.2295113104);
const float weight_3[3] = float[](0.2363835085, 0.3171515027, 0.0646567430);

// 5x5 Gaussian kernel (sigma = 2.9)
const float offset_5[5] = float[](0.0000000000, 1.4555280585, 3.3974333045, 5.3420924600, 7.2907394421);
const float weight_5[5] = float[](0.1380111805, 0.2388463687, 0.1341306511, 0.0474511031, 0.0105662868);

// 7x7 Gaussian kernel (sigma = 4.1)
const float offset_7[7] = float[](0.0000000000, 1.4777066406, 3.4481348827, 5.4189254215, 7.3902734339, 9.3623590458, 11.3353431409);
const float weight_7[7] = float[](0.0975214978, 0.1812458690, 0.1352096667, 0.0797856780, 0.0372388185, 0.0137463396, 0.0040128794);

// 9x9 Gaussian kernel (sigma = 5.3)
const float offset_9[9] = float[](0.0000000000, 1.4866532248, 3.4688903624, 5.4512059823, 7.4336440007, 9.4162471134, 11.3990563913, 13.3821109079, 15.3654474080);
const float weight_9[9] = float[](0.0754095170, 0.1443061733, 0.1209673813, 0.0880555064, 0.0556604255, 0.0305515915, 0.0145617216, 0.0060266531, 0.0021657888);

// 11x11 Gaussian kernel (sigma = 6.5)
const float offset_11[11] = float[](0.0000000000, 1.4911251925, 3.4793017763, 5.4675015021, 7.4557374723, 9.4440226279, 11.4323696922, 13.4207911168, 15.4092990294, 17.3979051853, 19.3866209215);
const float weight_11[11] = float[](0.0614737399, 0.1193820700, 0.1061322380, 0.0858779674, 0.0632472719, 0.0423961642, 0.0258663363, 0.0143636713, 0.0072596641, 0.0033395367, 0.0013982100);

// 13x13 Gaussian kernel (sigma = 7.7)
const float offset_13[13] = float[](0.0000000000, 1.4936754933, 3.4852463149, 5.4768255215, 7.4684178822, 9.4600281362, 11.4516609822, 13.4433210681, 15.4350129807, 17.4267412357, 19.4185102684, 21.4103244242, 23.4021879501);
const float weight_13[13] = float[](0.0518860387, 0.1016153008, 0.0934305515, 0.0803234716, 0.0645683402, 0.0485311007, 0.0341070165, 0.0224124857, 0.0137707817, 0.0079113197, 0.0042497216, 0.0021344825, 0.0010024082);

// 15x15 Gaussian kernel (sigma = 8.9)
const float offset_15[15] = float[](
    0.0000000000, 1.4952658907, 3.4889552119, 5.4826480517, 7.4763464154,
    9.4700523014, 11.4637676984, 13.4574945831, 15.4512349176,
    17.4449906473, 19.4387636980, 21.4325559738, 23.4263693551,
    25.4202056958, 27.4140668218
);
const float weight_15[15] = float[](
    0.0448858246, 0.0883700583, 0.0829807847, 0.0740948154,
    0.0629123549, 0.0507951011, 0.0389982744, 0.0284712483,
    0.0197653746, 0.0130479070, 0.0081905627, 0.0048890391,
    0.0027750444, 0.0014977964, 0.0007687264
);

// 17x17 Gaussian kernel (sigma = 10.1)
const float offset_17[17] = float[](
    0.0000000000, 1.4963239561, 3.4914232509, 5.4865241936, 7.4816277243,
    9.4767347810, 11.4718462993, 13.4669632111, 15.4620864443,
    17.4572169220, 19.4523555617, 21.4475032748, 23.4426609656,
    25.4378295312, 27.4330098603, 29.4282028326, 31.4234093188
);

const float weight_17[17] = float[](
    0.0395500882, 0.0781389327, 0.0744102532, 0.0681412859,
    0.0600067471, 0.0508161825, 0.0413824448, 0.0324072640,
    0.0244051037, 0.0176738414, 0.0123081617, 0.0082426584,
    0.0053082723, 0.0032873867, 0.0019577624, 0.0011211938,
    0.0006174656
);

// 19x19 Gaussian kernel (sigma = 11.3)
const float offset_19[19] = float[](
    0.0000000000, 1.4970632337, 3.4931478955, 5.4892333976, 7.4853202198,
    9.4814088410, 11.4774997394, 13.4735933920, 15.4696902747,
    17.4657908614, 19.4618956245, 21.4580050343, 23.4541195589,
    25.4502396637, 27.4463658115, 29.4424984624, 31.4386380731,
    33.4347850970, 35.4309399840
);
const float weight_19[19] = float[](
    0.0353482097, 0.0700089326, 0.0673257090, 0.0627524079,
    0.0566893955, 0.0496358221, 0.0421221528, 0.0346455796,
    0.0276189404, 0.0213396887, 0.0159805237, 0.0115988723,
    0.0081594769, 0.0055632764, 0.0036763823, 0.0023546826,
    0.0014617252, 0.0008794692, 0.0005128580
);


uniform vec2 texture_size;

#ifndef KERNEL_SIZE
#error "KERNEL_SIZE undefined, should be 3, 5, 7, 9, 11, or 13"
#endif

#if KERNEL_SIZE == 3
    const float offset[KERNEL_SIZE] = offset_3;
    const float weight[KERNEL_SIZE] = weight_3;
#elif KERNEL_SIZE == 5
    const float offset[KERNEL_SIZE] = offset_5;
    const float weight[KERNEL_SIZE] = weight_5;
#elif KERNEL_SIZE == 7
    const float offset[KERNEL_SIZE] = offset_7;
    const float weight[KERNEL_SIZE] = weight_7;
#elif KERNEL_SIZE == 9
    const float offset[KERNEL_SIZE] = offset_9;
    const float weight[KERNEL_SIZE] = weight_9;
#elif KERNEL_SIZE == 11
    const float offset[KERNEL_SIZE] = offset_11;
    const float weight[KERNEL_SIZE] = weight_11;
#elif KERNEL_SIZE == 13
    const float offset[KERNEL_SIZE] = offset_13;
    const float weight[KERNEL_SIZE] = weight_13;
#elif KERNEL_SIZE == 15
    const float offset[KERNEL_SIZE] = offset_15;
    const float weight[KERNEL_SIZE] = weight_15;
#elif KERNEL_SIZE == 17
    const float offset[KERNEL_SIZE] = offset_17;
    const float weight[KERNEL_SIZE] = weight_17;
#elif KERNEL_SIZE == 19
    const float offset[KERNEL_SIZE] = offset_19;
    const float weight[KERNEL_SIZE] = weight_19;
#else
#error "KERNEL_SIZE undefined"
#endif

uniform int horizontal_or_vertical;

// src: https://www.rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
vec4 effect(vec4 vertex_color, Image image, vec2 texture_coords, vec2 frag_position)
{
    vec4 color = Texel(image, frag_position / texture_size.xy) * weight[0];
    float alpha = color.a * weight[0];

    #if HORIZONTAL_OR_VERTICAL == 1
        for (int i = 1; i < KERNEL_SIZE; i++) {
            float o = offset[i] / texture_size.y;
            vec4 sample1 = texture(image, (texture_coords + vec2(0.0, o)));
            vec4 sample2 = texture(image, (texture_coords - vec2(0.0, o)));
            color += sample1 * weight[i];
            color += sample2 * weight[i];
            alpha += sample1.a * weight[i];
            alpha += sample2.a * weight[i];
        }
    #elif HORIZONTAL_OR_VERTICAL == 0
        for (int i = 1; i < KERNEL_SIZE; i++) {
            float o = offset[i] / texture_size.x;
            vec4 sample1 = texture(image, (texture_coords + vec2(o, 0.0)));
            vec4 sample2 = texture(image, (texture_coords - vec2(o, 0.0)));
            color += sample1 * weight[i];
            color += sample2 * weight[i];
            alpha += sample1.a * weight[i];
            alpha += sample2.a * weight[i];
        }
    #endif

    color.a = alpha;
    return color;
}

#endif